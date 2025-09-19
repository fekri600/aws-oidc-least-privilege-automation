terraform {
  backend "s3" {
    bucket         = "tf-rds-cross-region-dr-state-bc512bec"
    key            = "envs/storage/terraform.tfstate"
    region         = "us-east-1"
    use_lockfile   = true
    encrypt        = true
  }
}
