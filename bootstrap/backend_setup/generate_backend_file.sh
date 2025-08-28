#!/usr/bin/env bash
set -e
BUCKET_NAME="$1"
KEY="$2"
REGION="$3"
DYNAMODB_TABLE_NAME="$4"
OUTPUT_FILE="$5"
# Generate the backend.tf file in the bootstrap-improve root directory
cat > "${OUTPUT_FILE}" <<EOF
terraform {
  backend "s3" {
    bucket         = "${BUCKET_NAME}"
    key            = "${KEY}"
    region         = "${REGION}"
    dynamodb_table = "${DYNAMODB_TABLE_NAME}"
    encrypt        = true
  }
}
EOF


