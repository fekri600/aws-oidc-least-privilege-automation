#!/usr/bin/env python3
import argparse
import json
import time
import datetime as dt
from typing import Any, Dict, List, Optional, Set, Tuple

import boto3
from botocore.exceptions import ClientError

# Noise filtering
NOISE_ACTIONS = {
    "sts:GetCallerIdentity",
    "cloudtrail:StartQuery",
    "cloudtrail:GetQueryResults",
}
NOISE_PREFIXES = (
    "access-analyzer:",  # calls made by the generator itself
)

DEFAULT_PRESERVE_SIDS = {"S3StateManagement"}

def jdump(obj: Any) -> str:
    try:
        return json.dumps(obj, indent=2, default=str)
    except Exception:
        return str(obj)

def log(msg: str) -> None:
    print(msg, flush=True)

def wait_policy(access, job_id: str, timeout_s: int = 900, poll_s: int = 4) -> Dict[str, Any]:
    t0 = time.time()
    while True:
        r = access.get_generated_policy(
            jobId=job_id,
            includeResourcePlaceholders=True,
            includeServiceLevelTemplate=False,
        )
        status = r["jobDetails"]["status"]
        log(f"[*] Job {job_id} status: {status}")
        if status in ("SUCCEEDED", "FAILED", "CANCELED"):
            return r
        if (time.time() - t0) > timeout_s:
            try:
                access.cancel_policy_generation(jobId=job_id)
            finally:
                raise TimeoutError("Access Analyzer policy generation timed out")
        time.sleep(poll_s)

def build_cloudtrail_details(args, start: dt.datetime, end: dt.datetime) -> Dict[str, Any]:
    details: Dict[str, Any] = {"startTime": start, "endTime": end}
    explicit = bool(args.trail_arn) and bool(args.access_role_arn)
    if explicit:
        regions_list: List[str] = [r.strip() for r in args.regions.split(",") if r.strip()]
        trail_spec: Dict[str, Any] = {"cloudTrailArn": args.trail_arn}
        if regions_list:
            trail_spec["regions"] = regions_list
        else:
            trail_spec["allRegions"] = True
        details.update({
            "trails": [trail_spec],
            "accessRole": args.access_role_arn
        })
        log("[+] Using EXPLICIT mode (trail/accessRole provided)")
    else:
        log("[+] Using AUTO mode (no trail/accessRole provided)")
    return details

def extract_service_error(result: Dict[str, Any]) -> Optional[str]:
    jd = result.get("jobDetails", {})
    for key in ("error", "jobError"):
        e = jd.get(key)
        if isinstance(e, dict):
            return f"{e.get('code','Unknown')}: {e.get('message','Unknown')}"
        if isinstance(e, str):
            return e
    gp = result.get("generatedPolicyResult", {})
    e = gp.get("error")
    if isinstance(e, dict):
        return f"{e.get('code','Unknown')}: {e.get('message','Unknown')}"
    if isinstance(e, str):
        return e
    return None

def s3_buckets_used_by_principal(cloudtrail, principal_arn: str, start: dt.datetime, end: dt.datetime) -> Set[str]:
    buckets: Set[str] = set()
    next_token = None

    def _principal_matches(ev_detail: Dict[str, Any]) -> bool:
        ui = ev_detail.get("userIdentity") or {}
        arn = ui.get("arn")
        if arn == principal_arn:
            return True
        if ui.get("type") == "AssumedRole":
            issuer = ((ui.get("sessionContext") or {}).get("sessionIssuer") or {})
            if issuer.get("arn") == principal_arn:
                return True
        return False

    while True:
        kwargs = {"StartTime": start, "EndTime": end, "MaxResults": 50}
        if next_token:
            kwargs["NextToken"] = next_token
        resp = cloudtrail.lookup_events(**kwargs)
        for e in resp.get("Events", []):
            try:
                detail = json.loads(e.get("CloudTrailEvent", "{}"))
            except Exception:
                continue
            if not _principal_matches(detail):
                continue

            rp = detail.get("requestParameters") or {}
            bn = rp.get("bucketName")
            if isinstance(bn, str) and bn:
                buckets.add(bn)

            for r in detail.get("resources") or []:
                if r.get("resourceType") in ("AWS::S3::Bucket", "s3"):
                    name = r.get("resourceName")
                    if isinstance(name, str) and name:
                        if name.startswith("arn:aws:s3:::"):
                            name = name.split("arn:aws:s3:::", 1)[1]
                        buckets.add(name)

        next_token = resp.get("NextToken")
        if not next_token:
            break

    return buckets

def replace_s3_placeholders(statements: List[Dict[str, Any]], s3_bucket_names: Set[str]) -> List[Dict[str, Any]]:
    if not s3_bucket_names:
        return statements
    concrete_arns = [f"arn:aws:s3:::{b}" for b in sorted(s3_bucket_names)]

    out: List[Dict[str, Any]] = []
    for s in statements:
        res = s.get("Resource")
        if isinstance(res, str) and res == "arn:aws:s3:::${BucketName}":
            s = {**s, "Resource": concrete_arns}
        elif isinstance(res, list):
            replaced = []
            changed = False
            for r in res:
                if r == "arn:aws:s3:::${BucketName}":
                    replaced.extend(concrete_arns)
                    changed = True
                else:
                    replaced.append(r)
            if changed:
                s = {**s, "Resource": replaced}
        out.append(s)
    return out

def load_existing_policy(path: str) -> Optional[Dict[str, Any]]:
    try:
        with open(path, "r") as f:
            return json.load(f)
    except FileNotFoundError:
        return None
    except Exception:
        log("[!] Warning: existing policy file present but not valid JSON; ignoring.")
        return None

def split_preserved(statements: List[Dict[str, Any]], preserve_sids: Set[str]) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
    keep, rest = [], []
    for s in statements:
        sid = s.get("Sid")
        (keep if sid in preserve_sids else rest).append(s)
    return keep, rest

def dedup_statements(stmts: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    seen = set()
    out = []
    for s in stmts:
        key = json.dumps(s, sort_keys=True)
        if key in seen:
            continue
        seen.add(key)
        out.append(s)
    return out

def main() -> None:
    ap = argparse.ArgumentParser(description="Generate least-priv IAM policy via IAM Access Analyzer from CloudTrail evidence")
    ap.add_argument("--principal-arn", required=True, help="Role/User ARN to analyze")
    ap.add_argument("--policy-path", required=True, help="File to write the generated JSON policy")
    ap.add_argument("--lookback-hours", type=int, default=24, help="Hours to analyze (max 2160)")
    ap.add_argument("--trail-arn", help="CloudTrail trail ARN (optional)")
    ap.add_argument("--access-role-arn", help="IAM role AA assumes to read the trail's S3 bucket (optional)")
    ap.add_argument("--regions", default="", help="CSV regions for the trail; omit to use allRegions=true")
    ap.add_argument("--keep-star-resources", action="store_true", help="Keep statements with Resource:'*' (default: drop)")
    ap.add_argument("--preserve-sids", default=",".join(sorted(DEFAULT_PRESERVE_SIDS)),
                    help="Comma-separated list of Sid values to preserve from existing policy file")
    args = ap.parse_args()

    end = dt.datetime.utcnow().replace(microsecond=0)
    start = end - dt.timedelta(hours=args.lookback_hours)

    access = boto3.client("accessanalyzer")
    cloudtrail = boto3.client("cloudtrail")

    cloudtrail_details = build_cloudtrail_details(args, start, end)
    params = {"policyGenerationDetails": {"principalArn": args.principal_arn}, "cloudTrailDetails": cloudtrail_details}
    log(f"[*] Request parameters: {jdump(params)}")

    try:
        resp = access.start_policy_generation(**params)
    except ClientError as e:
        log(f"[!] start_policy_generation failed: {e}")
        raise

    job_id = resp["jobId"]
    log(f"[+] Started Access Analyzer policy generation job: {job_id}")

    result = wait_policy(access, job_id)
    status = result["jobDetails"]["status"]
    if status != "SUCCEEDED":
        log(f"[!] Access Analyzer generation failed with status: {status}")
        log(f"[!] Full job details: {jdump(result)}")
        hint = extract_service_error(result)
        raise SystemExit(f"FAILED - {hint or 'Unknown cause'}")

    gen = result.get("generatedPolicyResult", {}).get("generatedPolicies", [])
    if not gen:
        raise SystemExit("No generated policy returned")

    policy_data = gen[0]["policy"]
    if isinstance(policy_data, str):
        try:
            policy_data = json.loads(policy_data)
        except json.JSONDecodeError as e:
            raise SystemExit(f"Failed to parse generated policy JSON: {e}")

    statements = policy_data.get("Statement", [])
    if not isinstance(statements, list):
        statements = [statements]

    def keep_action(action: str) -> bool:
        if action in NOISE_ACTIONS:
            return False
        for p in NOISE_PREFIXES:
            if action.startswith(p):
                return False
        return True

    # Filter noise
    filtered: List[Dict[str, Any]] = []
    for s in statements:
        acts = s.get("Action")
        if isinstance(acts, str):
            if not keep_action(acts):
                continue
        elif isinstance(acts, list):
            acts = [a for a in acts if keep_action(a)]
            if not acts:
                continue
            s = {**s, "Action": acts}
        filtered.append(s)

    # Replace S3 placeholders with concrete buckets used by this principal
    used_buckets = s3_buckets_used_by_principal(cloudtrail, args.principal_arn, start, end)
    filtered = replace_s3_placeholders(filtered, used_buckets)

    # Optionally drop star resources
    tmp: List[Dict[str, Any]] = []
    for s in filtered:
        res = s.get("Resource")
        if not args.keep_star_resources:
            if res == "*" or (isinstance(res, list) and any(r == "*" for r in res)):
                continue
        tmp.append(s)
    generated_out = tmp

    # Preserve specific statements from existing file (e.g., your S3StateManagement block)
    existing = load_existing_policy(args.policy_path)
    preserve_sids = {s.strip() for s in (args.preserve_sids or "").split(",") if s.strip()}
    preserved: List[Dict[str, Any]] = []
    if existing:
        ex_statements = existing.get("Statement", [])
        if not isinstance(ex_statements, list):
            ex_statements = [ex_statements]
        keep, _rest = split_preserved(ex_statements, preserve_sids)
        preserved = keep

    # Merge preserved + generated, dedup, and write
    final_statements = dedup_statements(preserved + generated_out)
    policy_out = {"Version": "2012-10-17", "Statement": final_statements}

    with open(args.policy_path, "w") as f:
        json.dump(policy_out, f, indent=2)
    log(f"[+] Wrote least-privilege policy to {args.policy_path}")

if __name__ == "__main__":
    main()
