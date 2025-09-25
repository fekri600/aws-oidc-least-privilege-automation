#!/usr/bin/env python3
import argparse, json, time, datetime as dt
import boto3

NOISE_ACTIONS = {
    "cloudtrail:StartQuery",
    "cloudtrail:GetQueryResults",
    "sts:GetCallerIdentity",
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
    ap.add_argument("--principal-arn", required=True, help="Role ARN to right-size")
    ap.add_argument("--trail-arn", required=True, help="CloudTrail trail ARN")
    ap.add_argument("--access-role-arn", required=True,
                    help="ARN of role that Access Analyzer uses to read the trail (must have S3 read on the trail bucket)")
    ap.add_argument("--regions", default="", help="Comma list of regions that the trail covers (e.g., us-east-1,us-west-2). Leave empty to use allRegions=true")
    ap.add_argument("--lookback-hours", type=int, default=168, help="Hours of activity to analyze (max 2160 ~= 90 days)")
    ap.add_argument("--policy-path", required=True, help="Path to overwrite (permission-policy.json)")
    args = ap.parse_args()

    end = dt.datetime.utcnow().replace(microsecond=0)
    start = end - dt.timedelta(hours=args.lookback_hours)

    access = boto3.client("accessanalyzer")

    trails = [{
        "cloudTrailArn": args.trail_arn,
        **({"regions": [r.strip() for r in args.regions.split(",") if r.strip()], "allRegions": False}
           if args.regions.strip() else {"allRegions": True})
    }]

    resp = access.start_policy_generation(
        policyGenerationDetails={"principalArn": args.principal_arn},
        cloudTrailDetails={
            "trails": trails,
            "accessRole": args.access_role_arn,
            "startTime": start,
            "endTime": end,
        }
    )
    job_id = resp["jobId"]

    result = wait_policy(access, job_id)
    status = result["jobDetails"]["status"]
    if status != "SUCCEEDED":
        raise SystemExit(f"Access Analyzer generation status: {status}")

    gen = result["generatedPolicyResult"]["generatedPolicies"]
    if not gen:
        raise SystemExit("No generated policy returned")

    statements = gen[0]["policy"].get("Statement", [])
    # Optional: drop noise
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
    print(f"Wrote generated policy to {args.policy_path}")

if __name__ == "__main__":
    main()
