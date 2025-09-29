terraform {
  backend "s3" {
    bucket         = "aws-ci-least-privilege-automation-state-97dc01c2"
    key            = "envs/terraform.tfstate"
    region         = "us-east-1"
    use_lockfile   = true
    encrypt        = true
  }
}
