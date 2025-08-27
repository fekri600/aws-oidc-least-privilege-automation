# Lambda snapshot Function (OUTSIDE VPC)
module "lambda_snapshot" {
  source           = "../../../../modules/lambda" # or ./modules/lambda-function if that's your path
  function_name    = "${var.name_prefix}-lambda-snapshot"
  role_arn         = var.lambda_snapshot_role_arn
  handler          = "handler.lambda_handler" # must match your file, e.g., services/rds-snapshot/src/handler.py
  runtime          = "python3.12"
  s3_bucket        = var.artifacts_bucket_name
  s3_key           = var.rds_snapshot_s3_key
  source_code_hash = var.rds_snapshot_code_hash
  environment_variables = {
    DB_INSTANCE_ID = var.db_instance_id
    SNS_TOPIC_ARN  = var.sns_topic_arn
    ACCOUNT_ID     = data.aws_caller_identity.current.account_id
  }
}


module "eventbridge" {
  source              = "../../../../modules/eventbridge"
  name                = "${var.name_prefix}-lfn-snap-event"
  lambda_arn          = module.lambda_snapshot.lambda_arn
  lambda_name         = module.lambda_snapshot.lambda_name
  schedule_expression = "rate(1 hour)"
}


# Failover Lambda (PRIMARY region, OUTSIDE VPC)
module "lambda_failover" {
  source        = "../../../../modules/lambda" # or ./modules/lambda-function
  function_name = "${var.name_prefix}-lambda-failover"
  role_arn      = var.lambda_failover_role_arn
  handler       = "handler.lambda_handler" # <-- ensure it matches your file
  runtime       = "python3.12"

  s3_bucket        = var.artifacts_bucket_name
  s3_key           = var.rds_failover_s3_key
  source_code_hash = var.rds_failover_code_hash

  environment_variables = {
    DB_INSTANCE_CLASS      = var.db_instance_class
    SUBNET_GROUP_NAME      = var.db_subnet_group_name_2nd # <-- from secondary region module
    SNS_TOPIC_ARN          = var.sns_topic_arn
    PRIMARY_ENDPOINT_PARAM = var.primary_endpoint_name # outputs from modules/ssm
    ACTIVE_ENDPOINT_PARAM  = var.active_endpoint_name
    ROUTE53_ZONE_ID        = var.route53_zone_id
    DNS_RECORD_NAME        = var.db_dns_record_name # e.g., "db.internal.fekri.ca"
  }
}

resource "aws_lambda_permission" "sf_invoke_failover" {
  statement_id  = "AllowSFInvokeFailover"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_failover.lambda_name 
  principal     = "states.amazonaws.com"
}


module "step_functions" {
  source   = "../../../../modules/step-functions"
  role_arn = var.step_functions_role_arn
  name     = "${var.name_prefix}-rds-dr-sfn"
  state_machine_definition = templatefile("${path.module}/state_machine.json", {
    sns_topic_arn       = var.sns_topic_arn
    lambda_failover_arn = module.lambda_failover.lambda_arn
  })
  enable_logging            = true
  logging_level             = "ALL"
  include_execution_data    = true
  cloudwatch_log_group_name = var.cloudwatch_log_group_name
  tags = {
    Name = "${var.name_prefix}-rds-dr-sfn"
  }
}
