terraform {
  backend "s3" {
    bucket         = "aws-ci-least-privilege-automation-state-0534b6fb"
    key            = "envs/storage/terraform.tfstate"
    region         = "us-east-1"
    use_lockfile   = true
    encrypt        = true
  }
}
