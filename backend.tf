terraform {
  backend "s3" {
    bucket         = "aws-oidc-least-privilege-automation-state-ace3823d"
    key            = "envs/terraform.tfstate"
    region         = "us-east-1"
    use_lockfile   = true
    encrypt        = true
  }
}
