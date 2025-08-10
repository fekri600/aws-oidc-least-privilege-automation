
# Package Lambda functions
resource "null_resource" "package_snapshot_lambda" {
  provisioner "local-exec" {
    command = "zip -j lambda_src/snapshot_lambda.zip lambda_src/snapshot_lambda.py"
  }
}

resource "null_resource" "package_failover_lambda" {
  provisioner "local-exec" {
    command = "zip -j lambda_src/failover_lambda.zip lambda_src/failover_lambda.py"
  }
}

module "security_groups" {
  source = "../modules/security_groups"
  name   = "${local.name_prefix}"
  vpc_id = var.vpc_id
}

# SNS Topic for Notifications
module "sns" {
  source = "../modules/sns"
  name               = "${local.name_prefix}-sns-topic"
  email_subscription = var.email_subscription

}

# RDS Instance in Primary Region
module "rds" {
  source            = "../modules/rds"
  name              = "${local.name_prefix}-rds"
  vpc_id            = var.vpc_id
  security_group_id = module.security_groups.rds_sg_id
  subnet_ids        = var.subnet_ids
  db_instance_class = var.db_instance_class
  db_name           = var.db_name
  db_username       = data.aws_ssm_parameter.db_username.value 
  db_password       = data.aws_ssm_parameter.db_password.value

}
module "route53_record" {
  source = "../modules/route53_record"
  zone_id = var.route53_zone_id
  rds_endpoint = module.rds.rds_endpoint
}

module "ssm" {
  source                   = "../modules/ssm"
  db_primary_endpoint      = module.rds.rds_endpoint
  db_active_endpoint       = module.rds.rds_endpoint
  db_primary_endpoint_path = "/${var.project_name}/db/primary_endpoint"
  db_active_endpoint_path  = "/${var.project_name}/db/active_endpoint"
}

# Lambda snapshot Function
module "lambda_snapshot" {
  source = "../modules/lambda"

  function_name           = "${local.name_prefix}-lambda-snapshot"
  vpc_id                  = var.vpc_id
  role_arn                = var.lambda_snapshot_role_arn
  handler                 = "snapshot_lambda.lambda_handler"
  runtime                 = "python3.12"
  zip_file                = "${path.root}/lambda_src/snapshot_lambda.zip"
  private_subnet_ids      = var.subnet_ids
  security_group_id = module.security_groups.lambda_sg_id

  environment_variables = {
    DB_INSTANCE_ID = module.rds.rds_id
    SNS_TOPIC_ARN  = module.sns.sns_topic_arn
  }

}

# EventBridge Rule for Scheduled snapshot trigger
module "eventbridge" {
  source = "../modules/eventbridge"

  name                = "${local.name_prefix}-eventbridge"
  lambda_arn          = module.lambda_snapshot.lambda_arn
  lambda_name         = module.lambda_snapshot.lambda_name
  schedule_expression = "rate(1 hour)"

}

# Lambda failover Function
module "lambda_failover" {
  source = "../modules/lambda"

  function_name           = "${local.name_prefix}-lambda-failover"
  vpc_id                  = var.vpc_id
  role_arn                = var.lambda_failover_role_arn
  private_subnet_ids      = var.subnet_ids
  handler                 = "failover_lambda.lambda_handler"
  runtime                 = "python3.12"
  zip_file                = "${path.root}/lambda_src/failover_lambda.zip"
  security_group_id       = module.security_groups.lambda_sg_id
  environment_variables = {
    DB_INSTANCE_CLASS      = var.db_instance_class
    SUBNET_GROUP_NAME      = module.rds.db_subnet_group_name 
    SNS_TOPIC_ARN          = module.sns.sns_topic_arn
    PRIMARY_ENDPOINT_PARAM = module.ssm.primary_endpoint_path
    ACTIVE_ENDPOINT_PARAM  = module.ssm.active_endpoint_path
    ROUTE53_ZONE_ID        = var.route53_zone_id
    DNS_RECORD_NAME        = module.route53_record.record_name
  }

}


# Step Functions State Machine
module "step_functions" {
  source   = "../modules/step_functions"
  role_arn = var.step_functions_role_arn

  name                = "${local.name_prefix}-rds-dr"
  sns_topic_arn       = module.sns.sns_topic_arn
  lambda_failover_arn = module.lambda_failover.lambda_arn 


}




