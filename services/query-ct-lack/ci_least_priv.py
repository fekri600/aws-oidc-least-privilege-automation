#!/usr/bin/env python3
import argparse, json, os, time, datetime as dt
import boto3

def to_actions(event_source, event_name):
    """Convert CloudTrail eventSource + eventName to IAM action string."""
    svc = event_source.split(".")[0]
    return f"{svc}:{event_name}"

def start_query(client, eds, role_arn, start_time, end_time):
    # Extract Event Data Store ID (arn:aws:cloudtrail:region:account:eventdatastore/uuid)
    eds_id = eds.split('/')[-1] if '/' in eds else eds
    q = f"""
    SELECT eventSource, eventName
    FROM {eds_id}
    WHERE userIdentity.sessionContext.sessionIssuer.arn = '{role_arn}'
      AND eventTime BETWEEN from_iso8601_timestamp('{start_time}') 
                        AND from_iso8601_timestamp('{end_time}')
      AND errorCode IS NULL
    GROUP BY eventSource, eventName
    """
    print(f"Running query on Event Data Store: {eds_id}")
    r = client.start_query(QueryStatement=q)
    return r["QueryId"]

def wait_results(client, qid, timeout=60):
    start = time.time()
    while True:
        r = client.get_query_results(QueryId=qid)
        status = r["QueryStatus"]
        print(f"Query status: {status}")
        if status in ("FINISHED", "FAILED", "CANCELLED"):
            if status == "FAILED":
                print(f"Query failed. Full response: {r}")
            return r
        if time.time() - start > timeout:
            raise TimeoutError("CloudTrail Lake query timed out")
        time.sleep(2)

def parse_actions(res):
    actions = set()
    for row in res.get("QueryResultRows", []):
        # Parse the CloudTrail Lake result format: [{'eventSource': 'value'}, {'eventName': 'value'}]
        event_source = ""
        event_name = ""
        
        for item in row:
            if 'eventSource' in item:
                event_source = item['eventSource']
            elif 'eventName' in item:
                event_name = item['eventName']
        
        if event_source and event_name:
            actions.add(to_actions(event_source, event_name))
            print(f"Added action: {event_source}:{event_name}")
    
    return sorted(actions)

def build_policy(needed_actions):
    return {
        "Version": "2012-10-17",
        "Statement": [{
            "Sid": "LeastPrivAuto",
            "Effect": "Allow",
            "Action": sorted(needed_actions),
            "Resource": "*"   
        }]
    }

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--eds-arn", required=True)
    ap.add_argument("--role-arn", required=True)
    ap.add_argument("--policy-path", required=True,
                    help="Path to bootstrap/modules/oidc/policies/permission-policy.json")
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

    used_actions = parse_actions(res)
    print(f"Discovered {len(used_actions)} actions: {used_actions}")

    # Overwrite the original policy file with only the needed actions
    new_doc = build_policy(used_actions)
    with open(args.policy_path, "w") as f:
        json.dump(new_doc, f, indent=2)
    print(f"Policy overwritten at {args.policy_path}")


if __name__ == "__main__":
    main()