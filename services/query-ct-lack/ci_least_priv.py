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
    action_resources = {}  # Track resources per action
    
    for row in res.get("QueryResultRows", []):
        # Parse the CloudTrail Lake result format: [{'eventSource': 'value'}, {'eventName': 'value'}, {'resources': 'value'}]
        event_source = ""
        event_name = ""
        resources = ""
        
        for item in row:
            if 'eventSource' in item:
                event_source = item['eventSource']
            elif 'eventName' in item:
                event_name = item['eventName']
            elif 'resources' in item:
                resources = item['resources']
        
        if event_source and event_name:
            action = to_actions(event_source, event_name)
            actions.add(action)
            
            # Track resources for this action
            if action not in action_resources:
                action_resources[action] = set()
            if resources:
                action_resources[action].add(resources)
            
            print(f"Added action: {event_source}:{event_name}")
            if resources:
                print(f"  Resources: {resources}")
    
    return sorted(actions), action_resources

def build_policy(needed_actions, action_resources):
    statements = []
    
    # Create statements for actions with specific resources
    for action in sorted(needed_actions):
        if action in action_resources and action_resources[action]:
            # Convert set to sorted list for JSON serialization
            resources = sorted(list(action_resources[action]))
            statements.append({
                "Sid": f"LeastPrivAuto_{action.replace(':', '_').replace('-', '_')}",
                "Effect": "Allow",
                "Action": [action],
                "Resource": resources
            })
        else:
            # Actions without specific resources get wildcard
            statements.append({
                "Sid": f"LeastPrivAuto_{action.replace(':', '_').replace('-', '_')}",
                "Effect": "Allow",
                "Action": [action],
                "Resource": "*"
            })
    
    return {
        "Version": "2012-10-17",
        "Statement": statements
    }

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--eds-arn", required=True)
    ap.add_argument("--role-arn", required=True)
    ap.add_argument("--policy-path", required=True,
                    help="Path to bootstrap/modules/oidc/policies/permission-policy.json")
    ap.add_argument("--lookback-hours", type=int, default=24)
    ap.add_argument("--raw-output", 
                    help="Optional path to save raw query results as JSON file")
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

    # Save raw query results to JSON file if requested
    if args.raw_output:
        raw_data = {
            "query_metadata": {
                "query_id": qid,
                "eds_arn": args.eds_arn,
                "role_arn": args.role_arn,
                "start_time": start_s,
                "end_time": end_s,
                "lookback_hours": args.lookback_hours,
                "query_status": res["QueryStatus"],
                "timestamp": dt.datetime.utcnow().isoformat() + "Z"
            },
            "query_results": res
        }
        with open(args.raw_output, "w") as f:
            json.dump(raw_data, f, indent=2)
        print(f"Raw query results saved to {args.raw_output}")

    used_actions, action_resources = parse_actions(res)
    print(f"Discovered {len(used_actions)} actions: {used_actions}")
    
    # Print resource information
    for action in used_actions:
        if action in action_resources and action_resources[action]:
            print(f"Action {action} used resources: {sorted(action_resources[action])}")

    # Overwrite the original policy file with only the needed actions
    new_doc = build_policy(used_actions, action_resources)
    with open(args.policy_path, "w") as f:
        json.dump(new_doc, f, indent=2)
    print(f"Policy overwritten at {args.policy_path}")


if __name__ == "__main__":
    main()