#!/usr/bin/env python3
import argparse, json, time, datetime as dt
import boto3

NOISE_ACTIONS = {
    "sts:GetCallerIdentity",
    "cloudtrail:StartQuery",
    "cloudtrail:GetQueryResults",
}

def wait_policy(access, job_id, timeout_s=600):
    t0 = time.time()
    while True:
        r = access.get_generated_policy(jobId=job_id)
        status = r["jobDetails"]["status"]
        if status in ("SUCCEEDED", "FAILED", "CANCELED"):
            return r
        if time.time() - t0 > timeout_s:
            access.cancel_policy_generation(jobId=job_id)
            raise TimeoutError("Access Analyzer policy generation timed out")
        time.sleep(3)

def main():
    ap = argparse.ArgumentParser(
        description="Generate least-priv IAM policy via IAM Access Analyzer from CloudTrail"
    )
    ap.add_argument("--principal-arn", required=True, help="Role/User ARN to analyze")
    ap.add_argument("--trail-arn", required=True, help="CloudTrail trail ARN")
    ap.add_argument("--access-role-arn", required=True,
                    help="IAM role ARN that Access Analyzer will assume to read the CloudTrail S3 bucket")
    ap.add_argument("--regions", default="", help="Comma-separated regions for the trail (e.g. us-east-1,us-west-2). If empty, uses allRegions=true")
    ap.add_argument("--lookback-hours", type=int, default=168, help="Hours to analyze (max 2160 ~= 90 days)")
    ap.add_argument("--policy-path", required=True, help="Where to save the generated JSON policy")
    args = ap.parse_args()

    end = dt.datetime.utcnow().replace(microsecond=0)
    start = end - dt.timedelta(hours=args.lookback_hours)

    # Build trails entry correctly
    regions_list = [r.strip() for r in args.regions.split(",") if r.strip()]
    if regions_list:
        trail_spec = {"cloudTrailArn": args.trail_arn, "regions": regions_list}
    else:
        trail_spec = {"cloudTrailArn": args.trail_arn, "allRegions": True}

    access = boto3.client("accessanalyzer")

    resp = access.start_policy_generation(
        policyGenerationDetails={"principalArn": args.principal_arn},
        cloudTrailDetails={
            "trails": [trail_spec],
            "accessRole": args.access_role_arn,
            "startTime": start,
            "endTime": end,
        },
    )
    job_id = resp["jobId"]

    result = wait_policy(access, job_id)
    status = result["jobDetails"]["status"]
    if status != "SUCCEEDED":
        raise SystemExit(f"Access Analyzer generation failed: {status}")

    gen = result["generatedPolicyResult"]["generatedPolicies"]
    if not gen:
        raise SystemExit("No generated policy returned")

    statements = gen[0]["policy"].get("Statement", [])
    cleaned = []
    for s in statements:
        acts = s.get("Action")
        if isinstance(acts, str):
            if acts in NOISE_ACTIONS:
                continue
        elif isinstance(acts, list):
            acts = [a for a in acts if a not in NOISE_ACTIONS]
            if not acts:
                continue
            s = {**s, "Action": acts}
        cleaned.append(s)

    policy = {"Version": "2012-10-17", "Statement": cleaned or statements}
    with open(args.policy_path, "w") as f:
        json.dump(policy, f, indent=2)
    print(f"[+] Wrote least-privilege policy to {args.policy_path}")

if __name__ == "__main__":
    main()
