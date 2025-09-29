#!/usr/bin/env python3
import argparse
import json
import time
import datetime as dt
from typing import Any, Dict, List, Optional, Set, Tuple, Iterable
import re
from collections import defaultdict
import os

import boto3
from botocore.exceptions import ClientError
import botocore

# -------------------------
# Noise filtering
# -------------------------
NOISE_ACTIONS = {
    "sts:GetCallerIdentity",
    "cloudtrail:StartQuery",
    "cloudtrail:GetQueryResults",
}
NOISE_PREFIXES = (
    "access-analyzer:",  # calls made by the generator itself
)

DEFAULT_PRESERVE_SIDS = {"S3StateManagement"}

# -------------------------
# Small utils
# -------------------------
def jdump(obj: Any) -> str:
    try:
        return json.dumps(obj, indent=2, default=str)
    except Exception:
        return str(obj)

def log(msg: str) -> None:
    print(msg, flush=True)

# -------------------------
# Access Analyzer helpers
# -------------------------
def wait_policy(access, job_id: str, timeout_s: int = 900, poll_s: int = 4) -> Dict[str, Any]:
    t0 = time.time()
    while True:
        r = access.get_generated_policy(
            jobId=job_id,
            includeResourcePlaceholders=True,  # keep placeholders; we resolve them
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

# -------------------------
# Existing policy load/merge
# -------------------------
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

# -------------------------
# Generic placeholder / ARN bucketing
# -------------------------
PLACEHOLDER_RE = re.compile(r"\$\{[^}]+\}")
# arn:aws:<service>:<region>:<account>:<resource-part>
ARN_RE = re.compile(r"^arn:aws[a-zA-Z-]*:([^:]*):([^:]*):([^:]*):(.*)$")
ID_KEY_RE = re.compile(r"(?:^|[A-Za-z])(?:Id|ID|Arn|ARN|Name)$")
BUCKET_NAME_KEYS = {"bucketName", "Bucket", "bucket"}  # normalize S3 bucket names to ARNs

def _iter_strings(obj: Any) -> Iterable[str]:
    if isinstance(obj, str):
        yield obj
    elif isinstance(obj, dict):
        for v in obj.values():
            yield from _iter_strings(v)
    elif isinstance(obj, list):
        for v in obj:
            yield from _iter_strings(v)

def bucket_from_arn(arn: str) -> Optional[str]:
    m = ARN_RE.match(arn)
    if not m:
        return None
    service, _region, _account, resource_part = m.groups()
    if service == "s3":
        return "s3:bucket"
    sep_idx = len(resource_part)
    for ch in ("/", ":"):
        i = resource_part.find(ch)
        if i != -1:
            sep_idx = min(sep_idx, i)
    kind = resource_part[:sep_idx] if sep_idx > 0 else resource_part
    if not service or not kind:
        return None
    return f"{service}:{kind}"

def bucket_from_placeholder(resource_str: str) -> Optional[str]:
    stripped = PLACEHOLDER_RE.sub("X", resource_str)
    m = ARN_RE.match(stripped)
    if not m:
        return None
    service, _region, _account, resource_part = m.groups()
    if service == "s3":
        return "s3:bucket"
    sep_idx = len(resource_part)
    for ch in ("/", ":"):
        i = resource_part.find(ch)
        if i != -1:
            sep_idx = min(sep_idx, i)
    kind = resource_part[:sep_idx] if sep_idx > 0 else resource_part
    if not service or not kind:
        return None
    return f"{service}:{kind}"

# --- Generic helpers (Resource Explorer powered) ---
def flatten(obj: Any):
    if isinstance(obj, dict):
        for v in obj.values():
            yield from flatten(v)
    elif isinstance(obj, list):
        for v in obj:
            yield from flatten(v)
    else:
        yield obj

def extract_candidate_strings_from_event(detail: Dict[str, Any]) -> Set[str]:
    out: Set[str] = set()
    for r in detail.get("resources") or []:
        rn = r.get("resourceName")
        if isinstance(rn, str) and rn:
            out.add(rn)
    def harvest_kv(d: Dict[str, Any]):
        for k, v in d.items():
            if isinstance(v, (dict, list)):
                for leaf in flatten(v):
                    if isinstance(leaf, str) and leaf:
                        if k in BUCKET_NAME_KEYS:
                            out.add(f"arn:aws:s3:::{leaf}")
                        elif ID_KEY_RE.search(k):
                            out.add(leaf)
            else:
                if isinstance(v, str) and v:
                    if k in BUCKET_NAME_KEYS:
                        out.add(f"arn:aws:s3:::{v}")
                    elif ID_KEY_RE.search(k):
                        out.add(v)
    harvest_kv(detail.get("requestParameters") or {})
    harvest_kv(detail.get("responseElements") or {})
    return out

def resource_explorer_search_strings(strings: Set[str], regions: Optional[List[str]] = None) -> Set[str]:
    arns: Set[str] = set()
    candidate_regions = regions or []
    if not candidate_regions:
        try:
            candidate_regions = [boto3.session.Session().region_name or "us-east-1"]
        except Exception:
            candidate_regions = ["us-east-1"]
    for reg in dict.fromkeys(candidate_regions):
        try:
            rex = boto3.client("resource-explorer-2", region_name=reg)
        except Exception:
            continue
        for s in strings:
            if isinstance(s, str) and s.startswith("arn:aws"):
                arns.add(s); continue
            try:
                resp = rex.search(QueryString=s, MaxResults=100)
                for r in resp.get("Resources", []):
                    arn = r.get("Arn")
                    if isinstance(arn, str) and arn.startswith("arn:aws"):
                        arns.add(arn)
                token = resp.get("NextToken")
                while token:
                    resp = rex.search(QueryString=s, MaxResults=100, NextToken=token)
                    for r in resp.get("Resources", []):
                        arn = r.get("Arn")
                        if isinstance(arn, str) and arn.startswith("arn:aws"):
                            arns.add(arn)
                    token = resp.get("NextToken")
            except botocore.exceptions.ClientError:
                continue
            except Exception:
                continue
    return arns

def bucketize_arns(arns: Set[str]) -> Dict[str, Set[str]]:
    out: Dict[str, Set[str]] = defaultdict(set)
    for a in arns:
        b = bucket_from_arn(a)
        if b:
            out[b].add(a)
    return out

# -------------------------
# CloudTrail → evidence (generic)
# -------------------------
def collect_used_arns_from_cloudtrail_generic(cloudtrail, principal_arn: str, start: dt.datetime, end: dt.datetime) -> Dict[str, Set[str]]:
    found_arns: Set[str] = set()
    id_or_name_candidates: Set[str] = set()
    trail_regions: Set[str] = set()
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

            reg = detail.get("awsRegion")
            if isinstance(reg, str) and reg:
                trail_regions.add(reg)

            for r in detail.get("resources") or []:
                rn = r.get("resourceName")
                if isinstance(rn, str) and rn.startswith("arn:aws"):
                    found_arns.add(rn)
                else:
                    if isinstance(rn, str) and rn:
                        id_or_name_candidates.add(rn)

            id_or_name_candidates |= extract_candidate_strings_from_event(detail)

        next_token = resp.get("NextToken")
        if not next_token:
            break

    resolved = resource_explorer_search_strings(id_or_name_candidates, regions=list(trail_regions) or None)
    found_arns |= resolved

    return bucketize_arns(found_arns)

# -------------------------
# Terraform state auto-load from backend.tf (S3)
# -------------------------
BACKEND_BUCKET_RE = re.compile(r'^\s*bucket\s*=\s*"([^"]+)"\s*$', re.MULTILINE)
BACKEND_KEY_RE    = re.compile(r'^\s*key\s*=\s*"([^"]+)"\s*$', re.MULTILINE)
BACKEND_REGION_RE = re.compile(r'^\s*region\s*=\s*"([^"]+)"\s*$', re.MULTILINE)

def parse_backend_tf(path: str) -> Optional[Tuple[str, str, str]]:
    try:
        with open(path, "r") as f:
            data = f.read()
    except FileNotFoundError:
        return None
    b = BACKEND_BUCKET_RE.search(data)
    k = BACKEND_KEY_RE.search(data)
    r = BACKEND_REGION_RE.search(data)
    if b and k and r:
        return (b.group(1), k.group(1), r.group(1))
    return None

def load_tf_state_from_backend(backend_path: str) -> Optional[Dict[str, Any]]:
    cfg = parse_backend_tf(backend_path)
    if not cfg:
        log("[*] No backend.tf found or could not parse S3 backend; skipping TF state.")
        return None
    bucket, key, region = cfg
    log(f"[*] Reading Terraform state from s3://{bucket}/{key} (region {region})")
    s3 = boto3.client("s3", region_name=region)
    try:
        obj = s3.get_object(Bucket=bucket, Key=key)
        return json.loads(obj["Body"].read())
    except Exception as e:
        log(f"[!] Failed to read Terraform state: {e}")
        return None

def arns_from_tf_state_generic(state: Dict[str, Any]) -> Dict[str, Set[str]]:
    out: Dict[str, Set[str]] = defaultdict(set)
    if not state:
        return out
    for res in state.get("resources", []):
        for inst in res.get("instances", []):
            attrs = inst.get("attributes") or {}
            for s in _iter_strings(attrs):
                if isinstance(s, str) and s.startswith("arn:aws"):
                    b = bucket_from_arn(s)
                    if b:
                        out[b].add(s)
    return out

# -------------------------
# Evidence merge + replacement
# -------------------------
def merge_evidence(a: Dict[str, Set[str]], b: Dict[str, Set[str]], mode: str = "union") -> Dict[str, Set[str]]:
    keys = set(a.keys()) | set(b.keys())
    out: Dict[str, Set[str]] = {}
    for k in keys:
        if mode == "cloudtrail":
            out[k] = set(a.get(k, set()))
        elif mode == "tfstate":
            out[k] = set(b.get(k, set()))
        elif mode == "intersection":
            out[k] = set(a.get(k, set())) & set(b.get(k, set()))
        else:  # union
            out[k] = set(a.get(k, set())) | set(b.get(k, set()))
    return out

def replace_any_placeholders_with_bucket_arns(statements: List[Dict[str, Any]],
                                              bucket_to_arns: Dict[str, Set[str]],
                                              preserved_sids: Set[str],
                                              drop_unresolved: bool = False) -> List[Dict[str, Any]]:
    out: List[Dict[str, Any]] = []
    for s in statements:
        sid = s.get("Sid")
        if sid in preserved_sids:
            out.append(s)
            continue

        res = s.get("Resource")
        if res is None:
            out.append(s)
            continue

        items = res if isinstance(res, list) else [res]
        new_items: List[str] = []
        changed = False
        unresolved = False

        for it in items:
            if not (isinstance(it, str) and PLACEHOLDER_RE.search(it)):
                new_items.append(it)
                continue

            bucket = bucket_from_placeholder(it)
            if not bucket:
                new_items.append(it)
                unresolved = True
                continue

            arns = sorted(bucket_to_arns.get(bucket, set()))
            if arns:
                new_items.extend(arns)
                changed = True
            else:
                new_items.append(it)
                unresolved = True

        if drop_unresolved and unresolved:
            continue

        if changed:
            s = {**s, "Resource": new_items if isinstance(res, list) else (new_items[0] if new_items else res)}
        out.append(s)
    return out

# -------------------------
# Wildcardize variable tokens in Resource (ALWAYS ON)
# -------------------------
def _wildcardize_from_first_variable(s: str) -> str:
    """
    Replace everything from the first ${...} token to the end with '*'.
    Examples:
      arn:aws:route53:::change/${Id} -> arn:aws:route53:::change/*
      arn:aws:ec2:${Region}:${Account}:security-group/${SecurityGroupId} -> arn:aws:ec2:*
    """
    m = PLACEHOLDER_RE.search(s)
    return s if not m else (s[:m.start()] + "*")

def wildcardize_variable_resources(statements: List[Dict[str, Any]],
                                   preserved_sids: Set[str]) -> List[Dict[str, Any]]:
    out: List[Dict[str, Any]] = []
    for s in statements:
        if s.get("Sid") in preserved_sids:
            out.append(s); continue
        res = s.get("Resource")
        if res is None:
            out.append(s); continue

        if isinstance(res, list):
            changed = False
            new_res = []
            for r in res:
                if isinstance(r, str) and PLACEHOLDER_RE.search(r):
                    new_res.append(_wildcardize_from_first_variable(r)); changed = True
                else:
                    new_res.append(r)
            if changed:
                s = {**s, "Resource": new_res}
        elif isinstance(res, str) and PLACEHOLDER_RE.search(res):
            s = {**s, "Resource": _wildcardize_from_first_variable(res)}
        out.append(s)
    return out

# -------------------------
# Main
# -------------------------
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
    ap.add_argument("--backend-path", default="backend.tf", help="Path to Terraform backend.tf for auto-loading S3 state")
    ap.add_argument("--evidence-source", choices=["cloudtrail", "tfstate", "union", "intersection"], default="union",
                    help="Which evidence to use when replacing placeholders (default: union)")
    ap.add_argument("--drop-unresolved-placeholders", action="store_true",
                    help="Drop statements that still contain ${...} after replacement")
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

    # ----------------------------------
    # Filter noise
    # ----------------------------------
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
        if isinstance(acts, str):
            if not keep_action(acts):
                continue
        elif isinstance(acts, list):
            acts = [a for a in acts if keep_action(a)]
            if not acts:
                continue
            s = {**s, "Action": acts}
        filtered.append(s)

    # ----------------------------------
    # Generic placeholder replacement using CloudTrail + TF state evidence
    # ----------------------------------
    used_ct = collect_used_arns_from_cloudtrail_generic(cloudtrail, args.principal_arn, start, end)
    tf_state = load_tf_state_from_backend(args.backend_path)
    used_tf = arns_from_tf_state_generic(tf_state) if tf_state else {}
    evidence = merge_evidence(used_ct, used_tf, mode=args.evidence_source)

    preserve_sids = {s.strip() for s in (args.preserve_sids or "").split(",") if s.strip()}

    filtered = replace_any_placeholders_with_bucket_arns(
        filtered,
        bucket_to_arns=evidence,
        preserved_sids=preserve_sids,
        drop_unresolved=args.drop_unresolved_placeholders
    )

    # ALWAYS wildcardize any remaining ${...} in Resource from the first variable onward
    before = json.dumps(filtered, sort_keys=True)
    filtered = wildcardize_variable_resources(filtered, preserved_sids=preserve_sids)
    after = json.dumps(filtered, sort_keys=True)
    if before != after:
        log("[+] Wildcardized variable tokens in Resource (e.g., arn:.../${Id} → arn:.../*)")

    # ----------------------------------
    # Optionally drop star resources
    # ----------------------------------
    tmp: List[Dict[str, Any]] = []
    for s in filtered:
        res = s.get("Resource")
        if not args.keep_star_resources:
            if res == "*" or (isinstance(res, list) and any(r == "*" for r in res)):
                continue
        tmp.append(s)
    generated_out = tmp

    # ----------------------------------
    # Preserve specific statements from existing file (e.g., S3StateManagement)
    # ----------------------------------
    existing = load_existing_policy(args.policy_path)
    preserved: List[Dict[str, Any]] = []
    if existing:
        ex_statements = existing.get("Statement", [])
        if not isinstance(ex_statements, list):
            ex_statements = [ex_statements]
        keep, _rest = split_preserved(ex_statements, preserve_sids)
        preserved = keep

    # ----------------------------------
    # Merge preserved + generated, dedup, write
    # ----------------------------------
    final_statements = dedup_statements(preserved + generated_out)
    policy_out = {"Version": "2012-10-17", "Statement": final_statements}

    dirn = os.path.dirname(args.policy_path)
    if dirn:
        os.makedirs(dirn, exist_ok=True)
    with open(args.policy_path, "w") as f:
        json.dump(policy_out, f, indent=2)
    log(f"[+] Wrote least-privilege policy to {args.policy_path}")

if __name__ == "__main__":
    main()
