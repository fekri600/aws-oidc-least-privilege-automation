#!/usr/bin/env bash
set -e
BUCKET_NAME="$1"
REGION="$2"
KEY="$3"
OUTPUT_FILE="$4"
# Generate the backend.tf file in the specified location
cat > "${OUTPUT_FILE}" <<EOF
terraform {
  backend "s3" {
    bucket         = "${BUCKET_NAME}"
    key            = "${KEY}"
    region         = "${REGION}"
    use_lockfile   = true
    encrypt        = true
  }
}
EOF


