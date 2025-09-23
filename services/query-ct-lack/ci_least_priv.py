#!/usr/bin/env python3
import argparse, json, os, time, datetime as dt
import boto3

def to_actions(event_source, event_name):
    """
    Convert CloudTrail eventSource + eventName to IAM action string.
    Example: ec2.amazonaws.com + DescribeInstances -> ec2:DescribeInstances
    """
    svc = event_source.split(".")[0]
    return f"{svc}:{event_name}"

def start_query(client, eds, role_arn, start_time, end_time):
    # Extract Event Data Store ID from ARN (format: arn:aws:cloudtrail:region:account:eventdatastore/uuid)
    eds_id = eds.split('/')[-1] if '/' in eds else eds
    
    q = f"""
    SELECT eventSource, eventName
    FROM {eds_id}
    WHERE userIdentity.sessionContext.sessionIssuer.arn = '{role_arn}'
      AND eventTime BETWEEN from_iso8601_timestamp('{start_time}') AND from_iso8601_timestamp('{end_time}')
      AND errorCode IS NULL
    GROUP BY eventSource, eventName
    """
    
    print(f"Running query on Event Data Store: {eds_id}")
    print(f"Query: {q}")
    
    r = client.start_query(QueryStatement=q)
    return r["QueryId"]

def wait_results(client, qid, timeout=60):
    """
    Poll query until finished or timeout (seconds).
    """
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

def parse_rows(res):
    actions = set()
    for row in res.get("QueryResultRows", []):
        cols = row.get("Row", {}).get("Data", [])
        if len(cols) >= 2:
            event_source = cols[0].get("String", "")
            event_name = cols[1].get("String", "")
            if event_source and event_name:
                actions.add(to_actions(event_source, event_name))
    return sorted(actions)

def load_policy_actions(policy_path):
    with open(policy_path, "r") as f:
        doc = json.load(f)
    acts = set()
    for s in doc.get("Statement", []):
        if s.get("Effect") != "Allow":
            continue
        a = s.get("Action", [])
        if isinstance(a, str):
            a = [a]
        for x in a:
            acts.add(x)
    return doc, acts

def build_updated_policy(needed_actions):
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
    ap.add_argument("--policy-in", required=True)
    ap.add_argument("--policy-out", required=True)
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

    # Run query
    qid = start_query(client, args.eds_arn, args.role_arn, start_s, end_s)
    res = wait_results(client, qid)
    if res["QueryStatus"] != "FINISHED":
        raise SystemExit(f"Query failed: {res['QueryStatus']}")

    used_actions = set()
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
            used_actions.add(to_actions(event_source, event_name))
            print(f"Added action: {event_source}:{event_name}")

    base_doc, current_actions = load_policy_actions(args.policy_in)
    missing = sorted(used_actions - current_actions)
    unused = sorted(current_actions - used_actions)

    # Conservative: union (keep old + add missing)
    updated = sorted(current_actions | used_actions)
    new_doc = build_updated_policy(updated)

    with open(args.policy_out, "w") as f:
        json.dump(new_doc, f, indent=2)

    report = {
        "window_utc": {"start": start_s, "end": end_s},
        "used_actions": sorted(used_actions),
        "current_actions": sorted(current_actions),
        "missing_actions_added": missing,
        "unused_actions_candidates": unused,
        "policy_out": os.path.basename(args.policy_out)
    }
    with open(args.report_out, "w") as f:
        json.dump(report, f, indent=2)

    print("Updated policy written to", args.policy_out)
    print("Report written to", args.report_out)

if __name__ == "__main__":
    main()