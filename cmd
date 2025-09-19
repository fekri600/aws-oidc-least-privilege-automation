

export ACCOUNT_ID=490004637046
export REGION=us-east-1
export CI_ROLE_NAME=AWS_OIDC_ROLE_ARN
export CI_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${CI_ROLE_NAME}"


export TRAIL_BUCKET="ct-logs-${ACCOUNT_ID}-$(date +%Y%m%d%H%M%S)"
aws s3 mb "s3://${TRAIL_BUCKET}" --region ${REGION}


export TRAIL_NAME="my-org-trail"
aws cloudtrail create-trail \
  --name "${TRAIL_NAME}" \
  --s3-bucket-name "${TRAIL_BUCKET}" \
  --is-multi-region-trail \
  --region ${REGION}

aws cloudtrail start-logging --name "${TRAIL_NAME}" --region ${REGION}


aws cloudtrail describe-trails --region ${REGION} \
  --query "trailList[].{Name:Name,TrailARN:TrailARN,S3Bucket:S3BucketName,IsMulti:IsMultiRegionTrail}" \
  --output table

export TRAIL_ARN=$(aws cloudtrail describe-trails --region ${REGION} --query "trailList[0].TrailARN" --output text)
echo "TRAIL_ARN=${TRAIL_ARN}"


aws cloudtrail describe-trails --region us-east-1
aws cloudtrail start-logging --name org-trail --region us-east-1
aws cloudtrail get-trail-status --name org-trail --region us-east-1



JOB_ID="2a41f8a7-6b95-4a66-9144-333ba03c1bf9"
aws accessanalyzer get-generated-policy \
  --region us-east-1 \
  --job-id "$JOB_ID" \
  --include-resource-placeholders \
  --output json > generated-policy.json
