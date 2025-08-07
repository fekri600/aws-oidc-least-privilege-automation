module "ipam" {
  source      = "../../modules/ipam"
  environment = var.environment
}

# VPC for Primary Region
module "vpc" {
  source = "../../modules/vpc"

  name     = "${local.name_prefix}-vpc"
  vpc_cidr = module.ipam.vpc_cidr
}



# Subnets for Primary Region
module "subnet_public_az_1" {
  source = "../../modules/subnet"

  name                    = "${local.name_prefix}-subnet-pub-1"
  vpc_id                  = module.vpc.vpc_id
  cidr_block              = module.ipam.publics[0]
  availability_zone       = var.availability_zones_1st[0]
  map_public_ip_on_launch = true
  route_table_id          = module.route_to_igw_az_1.route_table_id
}

module "subnet_public_az_2" {
  source = "../../modules/subnet"

  name                    = "${local.name_prefix}-subnet-pub-2"
  vpc_id                  = module.vpc.vpc_id
  cidr_block              = module.ipam.publics[1]
  availability_zone       = var.availability_zones_1st[1]
  map_public_ip_on_launch = true
  route_table_id          = module.route_to_igw_az_2.route_table_id

}

module "subnet_private_az_1" {
  source = "../../modules/subnet"

  name                    = "${local.name_prefix}-subnet-priv-1"
  vpc_id                  = module.vpc.vpc_id
  cidr_block              = module.ipam.privates[0]
  availability_zone       = var.availability_zones_1st[0]
  map_public_ip_on_launch = false
  route_table_id          = module.route_to_nat_gw_az_1.route_table_id

}

module "subnet_private_az_2" {
  source = "../../modules/subnet"

  name                    = "${local.name_prefix}-subnet-priv-2"
  vpc_id                  = module.vpc.vpc_id
  cidr_block              = module.ipam.privates[1]
  availability_zone       = var.availability_zones_1st[1]
  map_public_ip_on_launch = false
  route_table_id          = module.route_to_nat_gw_az_2.route_table_id

}



# NAT Gateway for Primary Region
module "nat_gw_az_1" {
  source = "../../modules/nat_gw"

  name      = "${local.name_prefix}-nat-gw"
  subnet_id = module.subnet_public_az_1.subnet_id

}

module "nat_gw_az_2" {
  source = "../../modules/nat_gw"

  name      = "${local.name_prefix}-nat-gw"
  subnet_id = module.subnet_public_az_2.subnet_id


}

# Route Tables for Primary Region
module "route_to_igw_az_1" {
  source = "../../modules/route"

  name       = "${local.name_prefix}-rt-to-igw-az-1"
  vpc_id     = module.vpc.vpc_id
  gateway_id = module.vpc.igw_id


}

module "route_to_igw_az_2" {
  source = "../../modules/route"

  name       = "${local.name_prefix}-rt-to-igw-az-2"
  vpc_id     = module.vpc.vpc_id
  gateway_id = module.vpc.igw_id


}

module "route_to_nat_gw_az_1" {
  source = "../../modules/route"

  name       = "${local.name_prefix}-rt-to-nat-gw"
  vpc_id     = module.vpc.vpc_id
  gateway_id = module.nat_gw_az_1.nat_gateway_id


}

module "route_to_nat_gw_az_2" {
  source = "../../modules/route"

  name       = "${local.name_prefix}-rt-to-nat-gw-az-2"
  vpc_id     = module.vpc.vpc_id
  gateway_id = module.nat_gw_az_2.nat_gateway_id


}

# SNS Topic for Notifications
module "sns" {
  source = "../../modules/sns"

  name               = "${local.name_prefix}-sns-topic"
  email_subscription = var.email_subscription


}

# RDS Instance in Primary Region
module "rds" {
  source            = "../../modules/rds"
  name              = "${local.name_prefix}-rds"
  vpc_id            = module.vpc.vpc_id
  lambda_sg_id      = module.lambda_backup.security_group_id
  subnet_ids        = [module.subnet_private_az_1.subnet_id, module.subnet_private_az_2.subnet_id]
  db_instance_class = var.db_instance_class
  db_name           = var.db_name
  db_username       = data.aws_ssm_parameter.db_username.value
  db_password       = data.aws_ssm_parameter.db_password.value

}

# Lambda snapshot Function
module "lambda_snapshot" {
  source = "../../modules/lambda"

  function_name           = "${local.name_prefix}-lambda-snapshot"
  vpc_id                  = module.vpc.vpc_id
  role_arn                = module.iam.lambda_snapshot_role_arn
  handler                 = "snapshot_lambda.lambda_handler"
  runtime                 = "python3.12"
  zip_file                = "${path.root}/lambda_src/snapshot_lambda.zip"
  private_subnet_ids      = [module.subnet_private_az_1.subnet_id, module.subnet_private_az_2.subnet_id]
  input_security_group_id = module.rds.security_group_id

  environment_variables = {
    DB_INSTANCE_ID = module.rds.db_instance_id
    SNS_TOPIC_ARN  = module.sns.topic_arn
  }

}

# EventBridge Rule for Scheduled snapshot trigger
module "eventbridge" {
  source = "../../modules/eventbridge"

  name                = "${local.name_prefix}-eventbridge"
  lambda_arn          = module.lambda_snapshot.function_arn
  lambda_name         = module.lambda_snapshot.function_name
  schedule_expression = "rate(1 hour)"

}

# Lambda failover Function
module "lambda_failover" {
  source = "../../modules/lambda"

  function_name           = "${local.name_prefix}-lambda-snapshot"
  vpc_id                  = module.vpc.vpc_id
  role_arn                = module.iam.lambda_backup_role_arn
  input_security_group_id = module.rds.security_group_id
  private_subnet_ids      = [module.subnet_private_az_1.subnet_id, module.subnet_private_az_2.subnet_id]
  handler                 = "snapshot_lambda.lambda_handler"
  runtime                 = "python3.12"
  zip_file                = "${path.root}/lambda_src/snapshot_lambda.zip"
  environment_variables = {
    DB_INSTANCE_CLASS      = var.db_instance_class
    SUBNET_GROUP_NAME      = module.rds.subnet_group_name
    SNS_TOPIC_ARN          = module.sns.topic_arn
    PRIMARY_ENDPOINT_PARAM = module.ssm.db_primary_endpoint_path
    ACTIVE_ENDPOINT_PARAM  = module.ssm.db_active_endpoint_path
    ROUTE53_ZONE_ID        = module.route53.zone_id
    DNS_RECORD_NAME        = module.route53.record_name
  }


}


# Step Functions State Machine
module "step_functions" {
  source   = "../../modules/step_functions"
  role_arn = module.iam.step_functions_role_arn

  name                = "${local.name_prefix}-rds-dr"
  sns_topic_arn       = module.sns.topic_arn
  lambda_failover_arn = module.lambda_failover.function_arn


}

module "iam" {
  source      = "../../modules/iam"
  environment = "primary"
}

module "ssm" {
  source                   = "../../modules/ssm"
  db_primary_endpoint      = module.rds.db_primary_endpoint
  db_active_endpoint       = module.rds.db_active_endpoint
  db_primary_endpoint_path = "/${var.project_name}/db/primary_endpoint"
  db_active_endpoint_path  = "/${var.project_name}/db/active_endpoint"
}
