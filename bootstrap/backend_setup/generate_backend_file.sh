#!/usr/bin/env bash
set -e
BUCKET_NAME="$1"
REGION="$2"
DYNAMODB_TABLE_NAME="$3"
# Generate the backend.tf file in the bootstrap-improve root directory
cat > "../backend.tf" <<EOF
terraform {
  backend "s3" {
    bucket         = "${BUCKET_NAME}"
    key            = "envs/terraform.tfstate"
    region         = "${REGION}"
    dynamodb_table = "${DYNAMODB_TABLE_NAME}"
    encrypt        = true
  }
}
EOF


