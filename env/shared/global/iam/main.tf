resource "aws_iam_role" "lambda_snapshot_role" {
  name               = "${var.name_prefix}-lfn-rds-snap-rol"
  assume_role_policy = local.lambda_assume_role_policy
}

resource "aws_iam_role_policy" "lambda_snapshot_policy" {
  name   = "${var.name_prefix}-lfn-rds-snap-pol"
  role   = aws_iam_role.lambda_snapshot_role.id
  policy = local.lambda_snapshot_policy
}

resource "aws_iam_role" "lambda_failover_role" {
  name               = "${var.name_prefix}-lfn-rds-fail-rol"
  assume_role_policy = local.lambda_assume_role_policy
}

resource "aws_iam_role_policy" "lambda_failover_policy" {
  name   = "${var.name_prefix}-lfn-rds-fail-pol"
  role   = aws_iam_role.lambda_failover_role.id
  policy = local.lambda_failover_policy
}

resource "aws_iam_role" "step_functions_role" {
  name               = "${var.name_prefix}-sfn-rds-fail-rol"
  assume_role_policy = local.step_functions_assume_role_policy
}

resource "aws_iam_role_policy" "step_functions_policy" {
  name   = "${var.name_prefix}-sfn-rds-fail-pol"
  role   = aws_iam_role.step_functions_role.id
  policy = local.step_functions_policy
}


resource "aws_s3_bucket_policy" "artifacts" {
  bucket = var.artifacts_bucket_arn
  policy = local.artifacts_bucket_policy
}
