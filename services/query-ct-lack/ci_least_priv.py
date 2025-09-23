#!/usr/bin/env python3
import argparse, json, time, datetime as dt
import boto3

# ---------- Helpers ----------

def to_action(event_source, event_name):
    """Convert CloudTrail eventSource + eventName to IAM action string."""
    svc = event_source.split(".")[0]
    return f"{svc}:{event_name}"

def start_query(client, eds, role_arn, start_time, end_time):
    # Event Data Store ID (arn:aws:cloudtrail:region:account:eventdatastore/uuid)
    eds_id = eds.split('/')[-1] if '/' in eds else eds
    q = f"""
    SELECT eventSource, eventName, resources
    FROM {eds_id}
    WHERE userIdentity.sessionContext.sessionIssuer.arn = '{role_arn}'
      AND eventTime BETWEEN from_iso8601_timestamp('{start_time}') 
                        AND from_iso8601_timestamp('{end_time}')
      AND errorCode IS NULL
    """
    print(f"Running query on Event Data Store: {eds_id}")
    r = client.start_query(QueryStatement=q)
    return r["QueryId"]

def wait_results(client, qid, timeout=120):
    start = time.time()
    while True:
        r = client.get_query_results(QueryId=qid)
        status = r["QueryStatus"]
        if status in ("FINISHED", "FAILED", "CANCELLED"):
            return r
        if time.time() - start > timeout:
            raise TimeoutError("CloudTrail Lake query timed out")
        time.sleep(2)

def parse_actions(res):
    """Extract (action, resource) pairs from query results."""
    action_resources = set()
    for row in res.get("QueryResultRows", []):
        cols = [c.get("String", "") for c in row.get("Row", {}).get("Data", [])]
        if len(cols) >= 2:
            event_source, event_name = cols[0], cols[1]
            resources_json = cols[2] if len(cols) > 2 else ""
            action = to_action(event_source, event_name)

            # Default to "*" if no resources are parsed
            if not resources_json or resources_json.strip() == "":
                action_resources.add((action, "*"))
                continue

            try:
                resources = json.loads(resources_json)
                if isinstance(resources, list) and resources:
                    for r in resources:
                        arn = r.get("ARN") or r.get("arn") or "*"
                        action_resources.add((action, arn))
                else:
                    action_resources.add((action, "*"))
            except Exception:
                action_resources.add((action, "*"))
    return action_resources

def build_policy(action_resources):
    """Build IAM policy with one statement per unique (action, resource)."""
    statements = []
    for action, resource in sorted(action_resources):
        statements.append({
            "Effect": "Allow",
            "Action": action,
            "Resource": resource
        })
    return {"Version": "2012-10-17", "Statement": statements}

# ---------- Main ----------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--eds-arn", required=True)
    ap.add_argument("--role-arn", required=True)
    ap.add_argument("--policy-path", required=True,
                    help="Path to bootstrap/modules/oidc/policies/permission-policy.json")
    ap.add_argument("--report-out", required=True)
    ap.add_argument("--lookback-hours", type=int, default=24)
    args = ap.parse_args()

    end = dt.datetime.utcnow()
    start = end - dt.timedelta(hours=args.lookback_hours)
    start_s = start.replace(microsecond=0).isoformat() + "Z"
    end_s = end.replace(microsecond=0).isoformat() + "Z"

    client = boto3.client("cloudtrail")

    print(f"EDS ARN: {args.eds_arn}")
    print(f"Role ARN: {args.role_arn}")
    print(f"Time range: {start_s} to {end_s}")

    qid = start_query(client, args.eds_arn, args.role_arn, start_s, end_s)
    res = wait_results(client, qid)
    if res["QueryStatus"] != "FINISHED":
        raise SystemExit(f"Query failed: {res['QueryStatus']}")

    action_resources = parse_actions(res)
    print(f"Discovered {len(action_resources)} action/resource pairs")

    # Overwrite the original policy file
    new_doc = build_policy(action_resources)
    with open(args.policy_path, "w") as f:
        json.dump(new_doc, f, indent=2)
    print(f"Policy overwritten at {args.policy_path}")

    # Write a report for debugging
    report = {
        "window_utc": {"start": start_s, "end": end_s},
        "entries": sorted(list(action_resources))
    }
    with open(args.report_out, "w") as f:
        json.dump(report, f, indent=2)
    print(f"Report written to {args.report_out}")

if __name__ == "__main__":
    main()
