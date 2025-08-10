resource "aws_iam_role" "lambda_snapshot_role" {
  name               = "${var.project_name}-lambda-rds-snapshot-role"
  assume_role_policy = data.local_file.lambda_assume_role_policy.content
}

resource "aws_iam_role_policy" "lambda_snapshot_policy" {
  name   = "${var.project_name}-lambda-rds-snapshot-policy"
  role   = aws_iam_role.lambda_snapshot_role.id
  policy = data.local_file.lambda_snapshot_policy.content
}

resource "aws_iam_role" "lambda_failover_role" {
  name               = "${var.project_name}-lambda-rds-failover-role"
  assume_role_policy = data.local_file.lambda_assume_role_policy.content
}

resource "aws_iam_role_policy" "lambda_failover_policy" {
  name   = "${var.project_name}-lambda-rds-failover-policy"
  role   = aws_iam_role.lambda_failover_role.id
  policy = data.local_file.lambda_failover_policy.content
}

resource "aws_iam_role" "step_functions_role" {
  name               = "${var.project_name}-rds-dr-step-functions-role"
  assume_role_policy = data.local_file.step_functions_assume_role_policy.content
}

resource "aws_iam_role_policy" "step_functions_policy" {
    name   = "${var.project_name}-rds-dr-step-functions-policy"
  role   = aws_iam_role.step_functions_role.id
  policy = data.local_file.step_functions_policy.content
}
