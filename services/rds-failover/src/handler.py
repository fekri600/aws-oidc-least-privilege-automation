import boto3
import os
import datetime
import json

# ---- Clients (regionalized for RDS secondary) ----
rds_secondary = boto3.client("rds", region_name="us-west-1")  # Secondary region
ssm = boto3.client("ssm")
sns = boto3.client("sns")
route53 = boto3.client("route53")

# ---- Environment variables (fail fast if missing) ----
REQUIRED_ENVS = [
    "DB_INSTANCE_CLASS",
    "SUBNET_GROUP_NAME",
    "SNS_TOPIC_ARN",
    "PRIMARY_ENDPOINT_PARAM",
    "ACTIVE_ENDPOINT_PARAM",
    "ROUTE53_ZONE_ID",
    "DNS_RECORD_NAME",
]

def _env(name: str) -> str:
    v = os.environ.get(name)
    if not v:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return v

INSTANCE_CLASS = _env("DB_INSTANCE_CLASS")
SUBNET_GROUP = _env("SUBNET_GROUP_NAME")
SNS_TOPIC_ARN = _env("SNS_TOPIC_ARN")

PRIMARY_ENDPOINT_PARAM = _env("PRIMARY_ENDPOINT_PARAM")   # e.g. /db/prod/primary_endpoint
ACTIVE_ENDPOINT_PARAM = _env("ACTIVE_ENDPOINT_PARAM")     # e.g. /db/prod/endpoint
ROUTE53_ZONE_ID = _env("ROUTE53_ZONE_ID")                 # e.g. Zxxxxxxxxxxx
DNS_RECORD_NAME = _env("DNS_RECORD_NAME")                 # e.g. db.internal.fekri.ca


def lambda_handler(event, context):
    print(f"Received event: {json.dumps(event)}")
    action = (event or {}).get("action")

    try:
        if action == "find_latest_snapshot":
            # Note: consider filtering by DBInstanceIdentifier if you have multiple DBs
            paginator = rds_secondary.get_paginator("describe_db_snapshots")
            snapshots = []
            for page in paginator.paginate(SnapshotType="manual"):
                snapshots.extend(page.get("DBSnapshots", []))
            if not snapshots:
                raise RuntimeError("No manual snapshots found in secondary region.")

            snapshots.sort(key=lambda x: x["SnapshotCreateTime"], reverse=True)
            latest_snapshot = snapshots[0]["DBSnapshotIdentifier"]
            return {"id": latest_snapshot}

        elif action == "restore_db":
            snapshot_id = event["snapshot_id"]
            new_instance_id = f"restored-db-{datetime.datetime.utcnow().strftime('%Y%m%d%H%M')}"

            rds_secondary.restore_db_instance_from_db_snapshot(
                DBInstanceIdentifier=new_instance_id,
                DBSnapshotIdentifier=snapshot_id,
                DBInstanceClass=INSTANCE_CLASS,
                DBSubnetGroupName=SUBNET_GROUP,
                MultiAZ=False,
                PubliclyAccessible=False,
            )

            sns.publish(
                TopicArn=SNS_TOPIC_ARN,
                Subject="RDS Failover Triggered",
                Message=f"DB restored as {new_instance_id} from snapshot {snapshot_id}.",
            )

            return {"db_instance_id": new_instance_id}

        elif action == "check_db_status":
            db_instance_id = event["db_instance_id"]
            response = rds_secondary.describe_db_instances(DBInstanceIdentifier=db_instance_id)
            status = response["DBInstances"][0]["DBInstanceStatus"]
            return {"status": status}

        elif action == "update_ssm_and_dns":
            db_instance_id = event["db_instance_id"]
            response = rds_secondary.describe_db_instances(DBInstanceIdentifier=db_instance_id)
            db = response["DBInstances"][0]
            new_endpoint = db["Endpoint"]["Address"]

            # Update active endpoint parameter
            ssm.put_parameter(
                Name=ACTIVE_ENDPOINT_PARAM,
                Value=new_endpoint,
                Type="String",
                Overwrite=True,
            )

            # Update Route 53 CNAME
            route53.change_resource_record_sets(
                HostedZoneId=ROUTE53_ZONE_ID,
                ChangeBatch={
                    "Comment": "Failover DNS update",
                    "Changes": [
                        {
                            "Action": "UPSERT",
                            "ResourceRecordSet": {
                                "Name": DNS_RECORD_NAME,
                                "Type": "CNAME",
                                "TTL": 60,
                                "ResourceRecords": [{"Value": new_endpoint}],
                            },
                        }
                    ],
                },
            )

            sns.publish(
                TopicArn=SNS_TOPIC_ARN,
                Subject="Failover Complete: DNS & SSM Updated",
                Message=f"New DB endpoint: {new_endpoint}",
            )

            return {"new_endpoint": new_endpoint}

        else:
            raise ValueError("Invalid action")

    except Exception as e:
        # Send failure alert, then bubble up so Step Functions / EventBridge sees the error
        try:
            sns.publish(
                TopicArn=SNS_TOPIC_ARN,
                Subject="RDS Failover Failed",
                Message=str(e),
            )
        except Exception as publish_err:
            print(f"SNS publish failed: {publish_err}")

        raise
