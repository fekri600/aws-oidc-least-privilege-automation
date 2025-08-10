import boto3
import os
import datetime
import json

# ---- Clients (regionalized) ----
rds_primary = boto3.client("rds", region_name="us-east-1")
rds_secondary = boto3.client("rds", region_name="us-west-1")
sns = boto3.client("sns")

# ---- Environment variables ----
REQUIRED_ENVS = [
    "DB_INSTANCE_ID",
    "SNS_TOPIC_ARN",
    "ACCOUNT_ID"
]

def _env(name: str) -> str:
    v = os.environ.get(name)
    if not v:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return v

DB_INSTANCE_ID = _env("DB_INSTANCE_ID")
SNS_TOPIC_ARN = _env("SNS_TOPIC_ARN")
ACCOUNT_ID = _env("ACCOUNT_ID")


def lambda_handler(event, context):
    print(f"Received event: {json.dumps(event)}")
    timestamp = datetime.datetime.utcnow().strftime("%Y-%m-%d-%H-%M")
    snapshot_id = f"{DB_INSTANCE_ID}-snapshot-{timestamp}"

    try:
        # Create snapshot in primary region
        print(f"Creating snapshot in us-east-1: {snapshot_id}")
        rds_primary.create_db_snapshot(
            DBSnapshotIdentifier=snapshot_id,
            DBInstanceIdentifier=DB_INSTANCE_ID
        )

        # Copy snapshot to secondary region
        source_arn = f"arn:aws:rds:us-east-1:{ACCOUNT_ID}:snapshot:{snapshot_id}"
        target_snapshot_id = f"{snapshot_id}-copy"
        print(f"Copying snapshot to us-west-1 as: {target_snapshot_id}")

        rds_secondary.copy_db_snapshot(
            SourceDBSnapshotIdentifier=source_arn,
            TargetDBSnapshotIdentifier=target_snapshot_id
        )

        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject="RDS Snapshot Success",
            Message=f"Snapshot {snapshot_id} created in us-east-1 and copied to us-west-1."
        )

        return {"status": "success", "snapshot_id": snapshot_id, "copied_id": target_snapshot_id}

    except Exception as e:
        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject="RDS Snapshot Failed",
            Message=str(e)
        )
        raise
