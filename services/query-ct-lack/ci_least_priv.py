#!/usr/bin/env python3
import argparse
import json
import time
import datetime as dt
from typing import Any, Dict, List, Optional

import boto3
from botocore.exceptions import ClientError

# Noise filtering
NOISE_ACTIONS = {
    "sts:GetCallerIdentity",
    "cloudtrail:StartQuery",
    "cloudtrail:GetQueryResults",
}
NOISE_PREFIXES = (
    "access-analyzer:",  # calls made by this generator itself
)

def jdump(obj: Any) -> str:
    try:
        return json.dumps(obj, indent=2, default=str)
    except Exception:
        return str(obj)

def log(msg: str) -> None:
    print(msg, flush=True)

def wait_policy(access, job_id: str, timeout_s: int = 900, poll_s: int = 4) -> Dict[str, Any]:
    """Poll AA until job completes or times out.
       Ask for resource placeholders and disable service-level templates."""
    t0 = time.time()
    last = None
    while True:
        r = access.get_generated_policy(
            jobId=job_id,
            includeResourcePlaceholders=True,
            includeServiceLevelTemplate=False,
        )
        last = r
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
    """AUTO mode (only time range) or EXPLICIT mode (trail + access role)."""
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

def main() -> None:
    ap = argparse.ArgumentParser(
        description="Generate least-priv IAM policy via IAM Access Analyzer from CloudTrail evidence"
    )
    ap.add_argument("--principal-arn", required=True, help="Role/User ARN to analyze (the only principal this job targets)")
    ap.add_argument("--policy-path", required=True, help="File to write the generated JSON policy")
    ap.add_argument("--lookback-hours", type=int, default=24, help="Hours to analyze (max 2160)")

    # EXPLICIT mode (optional)
    ap.add_argument("--trail-arn", help="CloudTrail trail ARN (optional)")
    ap.add_argument("--access-role-arn", help="IAM role AA assumes to read the trail's S3 bucket (optional)")
    ap.add_argument("--regions", default="", help="CSV regions for the trail; omit to use allRegions=true")

    # Filtering switches
    ap.add_argument("--keep-star-resources", action="store_true",
                    help="Keep statements with Resource:'*' (default: drop them)")

    args = ap.parse_args()

    end = dt.datetime.utcnow().replace(microsecond=0)
    start = end - dt.timedelta(hours=args.lookback_hours)

    access = boto3.client("accessanalyzer")
    cloudtrail_details = build_cloudtrail_details(args, start, end)

    params = {
        "policyGenerationDetails": {"principalArn": args.principal_arn},
        "cloudTrailDetails": cloudtrail_details
    }
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
        if hint:
            raise SystemExit(f"FAILED - {hint}")
        raise SystemExit("FAILED - Unknown cause (see job details above)")

    gen = result.get("generatedPolicyResult", {}).get("generatedPolicies", [])
    if not gen:
        raise SystemExit("No generated policy returned")

    # Policy can be a dict or a JSON string
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

    filtered: List[Dict[str, Any]] = []
    for s in statements:
        acts = s.get("Action")

        # Normalize action(s)
        if isinstance(acts, str):
            if not keep_action(acts):
                continue
        elif isinstance(acts, list):
            acts = [a for a in acts if keep_action(a)]
            if not acts:
                continue
            s = {**s, "Action": acts}

        # Optionally drop star-resources
        res = s.get("Resource")
        if not args.keep_star_resources:
            if res == "*" or (isinstance(res, list) and any(r == "*" for r in res)):
                # Drop statements that AA could not scope to a resource
                continue

        filtered.append(s)

    policy_out = {"Version": "2012-10-17", "Statement": filtered}
    with open(args.policy_path, "w") as f:
        json.dump(policy_out, f, indent=2)
    log(f"[+] Wrote least-privilege policy to {args.policy_path}")

if __name__ == "__main__":
    main()
