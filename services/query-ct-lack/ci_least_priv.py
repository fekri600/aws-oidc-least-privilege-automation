#!/usr/bin/env python3
"""
Generate least-privilege IAM policy for a principal using IAM Access Analyzer.

Two modes:

1) AUTO mode (RECOMMENDED):
   Do NOT pass --trail-arn or --access-role-arn. Access Analyzer will auto-discover
   CloudTrail evidence in your account/org. Easiest and least brittle.

   Example:
     python ci_least_priv.py \
       --principal-arn arn:aws:iam::123456789012:role/github-ci-role \
       --policy-path bootstrap/modules/oidc/policies/permission-policy.json \
       --lookback-hours 72

2) EXPLICIT mode:
   Pass BOTH --trail-arn and --access-role-arn. Access Analyzer will use that trail and
   assume the given role to read the CloudTrail S3 bucket.

   Example:
     python ci_least_priv.py \
       --principal-arn arn:aws:iam::123456789012:role/github-ci-role \
       --trail-arn arn:aws:cloudtrail:us-east-1:123456789012:trail/main-trail \
       --access-role-arn arn:aws:iam::123456789012:role/aa-read-cloudtrail \
       --policy-path bootstrap/modules/oidc/policies/permission-policy.json \
       --lookback-hours 72
       # optionally: --regions us-east-1,us-west-2
"""

import argparse
import json
import time
import datetime as dt
from typing import Any, Dict, List, Optional

import boto3
from botocore.exceptions import ClientError

# Some calls are always present and not useful for granting
NOISE_ACTIONS = {
    "sts:GetCallerIdentity",
    "cloudtrail:StartQuery",
    "cloudtrail:GetQueryResults",
}

def jdump(obj: Any) -> str:
    """Safe pretty-printer (handles datetime, decimals, etc.)."""
    try:
        return json.dumps(obj, indent=2, default=str)
    except Exception:
        return str(obj)

def log(msg: str) -> None:
    print(msg, flush=True)

def wait_policy(access, job_id: str, timeout_s: int = 900, poll_s: int = 4) -> Dict[str, Any]:
    """Poll AA until job completes or times out."""
    t0 = time.time()
    while True:
        r = access.get_generated_policy(jobId=job_id)
        status = r["jobDetails"]["status"]
        log(f"[*] Job {job_id} status: {status}")
        if status in ("SUCCEEDED", "FAILED", "CANCELED"):
            return r
        if (time.time() - t0) > timeout_s:
            try:
                access.cancel_policy_generation(jobId=job_id)
            except Exception:
                pass
            raise TimeoutError("Access Analyzer policy generation timed out")
        time.sleep(poll_s)

def build_cloudtrail_details(args, start: dt.datetime, end: dt.datetime) -> Dict[str, Any]:
    """
    Build the cloudTrailDetails payload for StartPolicyGeneration.
    - AUTO mode: only start/end times.
    - EXPLICIT mode: requires trails + accessRole; supports regions list or allRegions.
    """
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
    """
    Try to pull a meaningful error from the AA response when status == FAILED.
    """
    # Some responses may include error details in jobDetails.error or generatedPolicyResult.error
    jd = result.get("jobDetails", {})
    jderr = jd.get("error")
    if isinstance(jderr, dict):
        code = jderr.get("code", "Unknown")
        msg  = jderr.get("message", "Unknown")
        return f"{code}: {msg}"

    gp = result.get("generatedPolicyResult", {})
    gperr = gp.get("error")
    if isinstance(gperr, dict):
        code = gperr.get("code", "Unknown")
        msg  = gperr.get("message", "Unknown")
        return f"{code}: {msg}"

    # Some regions may return a string error or none at all
    if jderr:
        return str(jderr)
    if gperr:
        return str(gperr)
    return None

def main() -> None:
    ap = argparse.ArgumentParser(
        description="Generate least-priv IAM policy via IAM Access Analyzer"
    )
    ap.add_argument("--principal-arn", required=True, help="Role/User ARN to analyze")
    ap.add_argument("--policy-path", required=True, help="File to write the generated JSON policy")
    ap.add_argument("--lookback-hours", type=int, default=24, help="Hours to analyze (max 2160 ~= 90 days)")

    # OPTIONAL for EXPLICIT mode
    ap.add_argument("--trail-arn", help="CloudTrail trail ARN (optional)")
    ap.add_argument("--access-role-arn", help="IAM role AA assumes to read the trail's S3 bucket (optional)")
    ap.add_argument("--regions", default="", help="CSV regions for the trail; omit to use allRegions=true in EXPLICIT mode")

    # OPTIONAL: keep all actions (disable noise filtering)
    ap.add_argument("--no-filter-noise", action="store_true", help="Do not remove common noise actions")

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
            log(f"[!] Service error: {hint}")
            raise SystemExit(f"FAILED - {hint}")
        else:
            # Generic hints that usually resolve failures
            log("[!] Hints:")
            log("    - Ensure the principal actually made AWS API calls within the lookback window.")
            log("    - If using EXPLICIT mode, verify the trail ARN/account/region and the access role’s S3/CloudTrail/KMS permissions.")
            log("    - If using AUTO mode, try a larger --lookback-hours (e.g., 72 or 168).")
            raise SystemExit("FAILED - Unknown cause (see job details above)")

    gen = result.get("generatedPolicyResult", {}).get("generatedPolicies", [])
    if not gen:
        raise SystemExit("No generated policy returned (no CloudTrail activity for the principal?)")

    # Handle both string and dict policy formats
    policy_data = gen[0]["policy"]
    if isinstance(policy_data, str):
        try:
            policy_data = json.loads(policy_data)
        except json.JSONDecodeError as e:
            raise SystemExit(f"Failed to parse generated policy JSON: {e}")
    
    statements = policy_data.get("Statement", [])
    if not args.no_filter_noise:
        filtered = []
        for s in statements:
            acts = s.get("Action")
            if isinstance(acts, str):
                if acts in NOISE_ACTIONS:
                    continue
            elif isinstance(acts, list):
                new_acts = [a for a in acts if a not in NOISE_ACTIONS]
                if not new_acts:
                    continue
                s = {**s, "Action": new_acts}
            filtered.append(s)
        statements = filtered

    policy = {"Version": "2012-10-17", "Statement": statements}
    with open(args.policy_path, "w") as f:
        json.dump(policy, f, indent=2)
    log(f"[+] Wrote least-privilege policy to {args.policy_path}")

if __name__ == "__main__":
    main()
