terraform {
  backend "s3" {
    bucket         = "backend-s3-bucket-2707"
    key            = "envs/artifacts/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "backend-d-db-table"
    encrypt        = true
  }
}
