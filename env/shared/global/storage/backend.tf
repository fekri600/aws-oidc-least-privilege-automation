terraform {
  backend "s3" {
    bucket         = "aws-ci-least-privilege-automation-state-97e54587"
    key            = "envs/storage/terraform.tfstate"
    region         = "us-east-1"
    use_lockfile   = true
    encrypt        = true
  }
}
