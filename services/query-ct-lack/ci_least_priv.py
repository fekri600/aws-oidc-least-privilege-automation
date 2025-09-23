#!/usr/bin/env python3
import argparse, json, os, time, datetime as dt
import boto3

def to_actions(row):
    # row: [eventSource, eventName]
    src, name = row
    # eventSource like ec2.amazonaws.com -> service prefix before dot
    svc = src.split(".")[0]
    # IAM action looks like "ec2:DescribeInstances"
    return f"{svc}:{name}"

def start_query(client, eds, role_arn, start_time, end_time):
    # Query events where the session issuer is the GitHub role
    q = f"""
    SELECT eventSource, eventName
    FROM {eds}
    WHERE userIdentity.sessionContext.sessionIssuer.arn = '{role_arn}'
      AND eventTime BETWEEN '{start_time}' AND '{end_time}'
      AND errorCode IS NULL
    GROUP BY eventSource, eventName
    """
    r = client.start_query(QueryStatement=q, EventDataStore=eds)
    return r["QueryId"]

def wait_results(client, qid, eds):
    while True:
        r = client.get_query_results(QueryId=qid, EventDataStore=eds)
        if r["Status"] in ("FINISHED", "FAILED", "CANCELLED"):
            return r
        time.sleep(2)

def parse_rows(res):
    actions = set()
    for row in res.get("QueryResultRows", []):
        # Each row has dicts with column value under "String"
        cols = [c.get("StringValue","") for c in row.get("Row", {}).get("ColumnInfo", [])]  # not used
        vals = [c.get("String","") for c in row.get("Row", {}).get("Data", [])]
        if vals and len(vals) >= 2:
            actions.add(to_actions(vals[:2]))
    return sorted(actions)

def load_policy_actions(policy_path):
    with open(policy_path, "r") as f:
        doc = json.load(f)
    acts = set()
    for s in doc.get("Statement", []):
        if s.get("Effect") != "Allow":
            continue
        a = s.get("Action", [])
        if isinstance(a, str): a = [a]
        for x in a:
            acts.add(x)
    return doc, acts

def build_updated_policy(base_doc, needed_actions):
    # single consolidated statement. Adjust to your structure if needed.
    new_doc = {
        "Version": "2012-10-17",
        "Statement": [{
            "Sid": "LeastPrivAuto",
            "Effect": "Allow",
            "Action": sorted(needed_actions),
            "Resource": "*"
        }]
    }
    return new_doc

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
    start_s = start.replace(microsecond=0).isoformat()+"Z"
    end_s   = end.replace(microsecond=0).isoformat()+"Z"

    client = boto3.client("cloudtrail")  # CloudTrail Lake uses cloudtrail client
    qid = start_query(client, args.eds_arn, args.role_arn, start_s, end_s)
    res = wait_results(client, qid, args.eds_arn)
    if res["Status"] != "FINISHED":
        raise SystemExit(f"Query failed: {res['Status']}")

    used_actions = set()
    for row in res["QueryResultRows"]:
        vals = [c.get("String","") for c in row["Row"]["Data"]]
        if len(vals) >= 2:
            used_actions.add(to_actions(vals[:2]))

    base_doc, current_actions = load_policy_actions(args.policy_in)
    missing = sorted(used_actions - current_actions)
    unused  = sorted(current_actions - used_actions)

    # Conservative: keep existing + add missing (you can flip to strict remove)
    updated = sorted(current_actions | used_actions)

    new_doc = build_updated_policy(base_doc, updated)

    with open(args.policy_out, "w") as f:
        json.dump(new_doc, f, indent=2)

    report = {
        "window_utc": {"start": start_s, "end": end_s},
        "used_actions": sorted(used_actions),
        "current_actions": sorted(current_actions),
        "missing_actions_will_add": missing,
        "unused_actions_candidates_for_removal": unused,
        "policy_out": os.path.basename(args.policy_out)
    }
    with open(args.report_out, "w") as f:
        json.dump(report, f, indent=2)

if __name__ == "__main__":
    main()
#!/usr/bin/env python3
import argparse, json, os, time, datetime as dt
import boto3

# ---------- Helpers ----------

def to_actions(event_source, event_name):
    """
    Convert CloudTrail eventSource + eventName to IAM action string.
    Example: ec2.amazonaws.com + DescribeInstances -> ec2:DescribeInstances
    """
    svc = event_source.split(".")[0]
    return f"{svc}:{event_name}"

def start_query(client, eds, role_arn, start_time, end_time):
    q = f"""
    SELECT eventSource, eventName
    FROM {eds}
    WHERE userIdentity.sessionContext.sessionIssuer.arn = '{role_arn}'
      AND eventTime BETWEEN from_iso8601_timestamp('{start_time}') 
                        AND from_iso8601_timestamp('{end_time}')
      AND errorCode IS NULL
    GROUP BY eventSource, eventName
    """
    r = client.start_query(QueryStatement=q, EventDataStore=eds)
    return r["QueryId"]

def wait_results(client, qid, timeout=60):
    """
    Poll query until finished or timeout (seconds).
    """
    start = time.time()
    while True:
        r = client.get_query_results(QueryId=qid)
        status = r["QueryStatus"]
        if status in ("FINISHED", "FAILED", "CANCELLED"):
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

# ---------- Main ----------

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

    # Run query
    qid = start_query(client, args.eds_arn, args.role_arn, start_s, end_s)
    res = wait_results(client, qid)
    if res["QueryStatus"] != "FINISHED":
        raise SystemExit(f"Query failed: {res['QueryStatus']}")

    used_actions = set()
    for row in res.get("QueryResultRows", []):
        vals = [c.get("String", "") for c in row["Row"]["Data"]]
        if len(vals) >= 2:
            used_actions.add(to_actions(vals[0], vals[1]))

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
