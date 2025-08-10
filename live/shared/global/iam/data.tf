# Data sources for IAM policy JSON files
data "local_file" "lambda_snapshot_policy" {
  filename = "${path.module}/policies/lambda_snapshot_policy.json"
}

data "local_file" "step_functions_policy" {
  filename = "${path.module}/policies/step_functions_policy.json"
}

data "local_file" "lambda_assume_role_policy" {
  filename = "${path.module}/policies/lambda_assume_role_policy.json"
}

data "local_file" "step_functions_assume_role_policy" {
  filename = "${path.module}/policies/step_functions_assume_role_policy.json"
} 


data "local_file" "lambda_failover_policy" {
  filename = "${path.module}/policies/lambda_failover_policy.json"
}


data "local_file" "lambda_assume_role_policy" {
  filename = "${path.module}/policies/lambda_assume_role_policy.json"
}

