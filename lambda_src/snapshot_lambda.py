import boto3
import os
import datetime

rds_primary = boto3.client('rds', region_name='us-east-1')
rds_secondary = boto3.client('rds', region_name='us-west-1')
sns = boto3.client('sns')

DB_INSTANCE_ID = os.environ['DB_INSTANCE_ID']
SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']

def lambda_handler(event, context):
    timestamp = datetime.datetime.utcnow().strftime('%Y-%m-%d-%H-%M')
    snapshot_id = f"{DB_INSTANCE_ID}-snapshot-{timestamp}"

    try:
        # Create snapshot in primary region
        rds_primary.create_db_snapshot(
            DBSnapshotIdentifier=snapshot_id,
            DBInstanceIdentifier=DB_INSTANCE_ID
        )

        # Copy snapshot to secondary region
        rds_secondary.copy_db_snapshot(
            SourceDBSnapshotIdentifier=f"arn:aws:rds:us-east-1:{os.environ['ACCOUNT_ID']}:snapshot:{snapshot_id}",
            TargetDBSnapshotIdentifier=f"{snapshot_id}-copy"
        )

        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject="RDS Snapshot Success",
            Message=f"Snapshot {snapshot_id} created and copied to us-west-1."
        )

        return {"status": "success"}

    except Exception as e:
        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject="RDS Snapshot Failed",
            Message=str(e)
        )
        raise e
