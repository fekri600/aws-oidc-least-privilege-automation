# IAM Role for Lambda Backup (Primary Region)
resource "aws_iam_role" "lambda_snapshot_role" {
  count              = var.environment == "primary" ? 1 : 0
  name               = "lambda-rds-backup-role"
  assume_role_policy = data.local_file.lambda_assume_role_policy.content
}

resource "aws_iam_role_policy" "lambda_snapshot_policy" {
  count  = var.environment == "primary" ? 1 : 0
  name   = "lambda-rds-snapshot-policy"
  role   = aws_iam_role.lambda_snapshot_role.id
  policy = data.local_file.lambda_backup_policy.content
}

# IAM Role for Lambda Failover (Secondary Region)
resource "aws_iam_role" "lambda_failover_role" {
  count              = var.environment == "secondary" ? 1 : 0
  name               = "lambda-rds-failover-role"
  assume_role_policy = data.local_file.lambda_assume_role_policy.content
}

resource "aws_iam_role_policy" "lambda_failover_policy" {
  count  = var.environment == "secondary" ? 1 : 0
  name   = "lambda-rds-failover-policy"
  role   = aws_iam_role.lambda_failover_role.id
  policy = data.local_file.lambda_failover_policy.content
}

# IAM Role for Step Functions (Primary Region)
resource "aws_iam_role" "step_functions_role" {
  count              = var.environment == "primary" ? 1 : 0
  name               = "rds-dr-step-functions-role"
  assume_role_policy = data.local_file.step_functions_assume_role_policy.content
}

resource "aws_iam_role_policy" "step_functions_policy" {
  count  = var.environment == "primary" ? 1 : 0
  name   = "rds-dr-step-functions-policy"
  role   = aws_iam_role.step_functions_role.id
  policy = data.local_file.step_functions_policy.content
} 