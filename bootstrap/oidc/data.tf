data "external" "github_repo" {
  program = ["bash", "${path.module}/scripts/get_repo.sh"]
}

# Get the current AWS region
data "aws_region" "current" {}

# Get the current AWS account ID
data "aws_caller_identity" "current" {}

