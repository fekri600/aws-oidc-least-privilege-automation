# Lambda snapshot Function (OUTSIDE VPC)
module "lambda_snapshot" {
  source  = "../modules/lambda"        # or ./modules/lambda-function if that's your path
  function_name = "${local.name_prefix}-lambda-snapshot"
  role_arn      = var.lambda_snapshot_role_arn
  handler       = "handler.lambda_handler"    # must match your file, e.g., services/rds-snapshot/src/handler.py
  runtime       = "python3.12"

  # pick ONE code source; example uses a local zip during dev
  zip_file = "${path.root}/lambda_src/snapshot_lambda.zip"

  s3_bucket        = var.artifacts_bucket_name
  s3_key           = "lambda/rds-snapshot/rds-snapshot-1.0.0.zip"
  source_code_hash = var.snapshot_code_hash
  environment_variables = {
    DB_INSTANCE_ID = var.db_instance_id
    SNS_TOPIC_ARN  = var.sns_topic_arn
    ACCOUNT_ID     = data.aws_caller_identity.current.account_id         
  }
}


module "eventbridge" {
  source              = "../modules/eventbridge"
  name                = "${local.name_prefix}-eventbridge"
  lambda_arn          = module.lambda_snapshot.lambda_arn
  lambda_name         = module.lambda_snapshot.lambda_name
  schedule_expression = "rate(1 hour)"
}


# Failover Lambda (PRIMARY region, OUTSIDE VPC)
module "lambda_failover" {
  source        = "../modules/lambda"  # or ./modules/lambda-function
  function_name = "${local.name_prefix}-lambda-failover"
  role_arn      = var.lambda_failover_role_arn
  handler       = "handler.lambda_handler"  # <-- ensure it matches your file
  runtime       = "python3.12"
  zip_file      = "${path.root}/lambda_src/failover_lambda.zip"

  s3_bucket        = var.artifacts_bucket_name
  s3_key           = "lambda/rds-failover/rds-failover-1.0.0.zip"
  source_code_hash = var.failover_code_hash

  environment_variables = {
    DB_INSTANCE_CLASS      = var.db_instance_class
    SUBNET_GROUP_NAME      = var.db_subnet_group_name_2nd  # <-- from secondary region module
    SNS_TOPIC_ARN          = var.sns_topic_arn
    PRIMARY_ENDPOINT_PARAM = var.primary_endpoint_name          # outputs from modules/ssm
    ACTIVE_ENDPOINT_PARAM  = var.active_endpoint_name
    ROUTE53_ZONE_ID        = var.route53_zone_id
    DNS_RECORD_NAME        = var.db_dns_record_name                            # e.g., "db.internal.fekri.ca"
  }
}

resource "aws_lambda_permission" "sf_invoke_failover" {
  statement_id  = "AllowSFInvokeFailover"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_failover.lambda_name
  principal     = "states.amazonaws.com"
}


module "step_functions" {
  source              = "../modules/step_functions"
  role_arn            = var.step_functions_role_arn
  name                = "${local.name_prefix}-rds-dr-sfn"
  sns_topic_arn       = var.sns_topic_arn
  lambda_failover_arn = module.lambda_failover.lambda_arn 
}
