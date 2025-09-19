locals {
  lambda_snapshot_policy = file("${path.module}/policies/lambda_snapshot_policy.json")

  step_functions_policy = file("${path.module}/policies/step_functions_policy.json")

  lambda_assume_role_policy = file("${path.module}/policies/lambda_assume_role_policy.json")

  step_functions_assume_role_policy = file("${path.module}/policies/step_functions_assume_role_policy.json")

  lambda_failover_policy = file("${path.module}/policies/lambda_failover_policy.json")

  artifacts_bucket_policy = templatefile("${path.module}/policies/artifacts_bucket_policy.json", {
    bucket_arn  = var.artifacts_bucket_arn
    prefix      = var.artifacts_prefix
    ci_role_arn = var.ci_role_arn
  })
}
