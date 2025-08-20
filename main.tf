module "prod_compute_1st" {
  source                   = "./env/prod/us-east-1/compute"
  name_prefix              = local.name_prefix.prod_1st
  db_name                  = var.db_name
  step_functions_role_arn  = module.iam.step_functions_role_arn
  lambda_snapshot_role_arn = module.iam.lambda_snapshot_role_arn
  lambda_failover_role_arn = module.iam.lambda_failover_role_arn
  db_instance_id           = module.prod_database_1st.db_instance_id
  db_instance_class        = var.db_instance_class
  db_subnet_group_name_2nd = module.prod_networking_2nd.db_subnet_group_name
  route53_zone_id          = module.dns_zone.zone_id
  primary_endpoint_name    = module.prod_database_1st.db_primary_endpoint
  active_endpoint_name     = module.prod_database_1st.db_active_endpoint
  db_dns_record_name       = module.prod_database_1st.db_dns_record_name
  sns_topic_arn            = module.sns.sns_topic_arn
  artifacts_bucket_name    = module.ssm.artifacts_bucket_name
  rds_snapshot_code_hash   = module.ssm.rds_snapshot_code_hash
  rds_failover_code_hash   = module.ssm.rds_failover_code_hash
  rds_snapshot_s3_key      = module.ssm.rds_snapshot_s3_key
  rds_failover_s3_key      = module.ssm.rds_failover_s3_key  
}

module "prod_database_1st" {
  source                = "./env/prod/us-east-1/database"
  name_prefix           = local.name_prefix.prod_1st
  db_name               = var.db_name
  db_instance_class     = var.db_instance_class
  vpc_id                = module.prod_networking_1st.vpc_id
  db_subnet_group_name  = module.prod_networking_1st.db_subnet_group_name
  rds_security_group_id = module.prod_security_1st.rds_security_group_id
  route53_zone_id       = module.dns_zone.zone_id
  db_username           = module.ssm.db_username
  db_password           = module.ssm.db_password
}

module "prod_security_1st" {
  source      = "./env/prod/us-east-1/security"
  name_prefix = local.name_prefix.prod_1st
  vpc_id      = module.prod_networking_1st.vpc_id
}

module "prod_networking_1st" {
  source             = "./env/prod/us-west-1/networking"
  name_prefix        = local.name_prefix.prod_1st
  availability_zones = var.availability_zones_1st
}

module "sns" {
  source             = "./env/prod/us-east-1/queuing"
  name_prefix        = local.name_prefix.prod_1st
  email_subscription = var.email_subscription
}

module "prod_networking_2nd" {
  source             = "./env/prod/us-east-1/networking"
  name_prefix        = local.name_prefix.prod_2nd
  availability_zones = var.availability_zones_2nd

  providers = {
    aws = aws.secondary
  }
}

module "ssm" {
  source              = "./env/shared/global/ssm"
  db_primary_endpoint = module.prod_database_1st.db_primary_endpoint
  db_active_endpoint  = module.prod_database_1st.db_active_endpoint
}


module "iam" {
  source               = "./env/shared/global/iam"
  name_prefix          = local.name_prefix.prod_glb
  artifacts_bucket_arn = module.storage.artifacts_bucket_arn
  ci_role_arn          = module.ssm.ci_role_arn
  artifacts_prefix     = "lambda/"
}

module "dns_zone" {
  source    = "./env/shared/global/dns"
  zone_name = var.zone_name
  vpc_1st   = module.prod_networking_1st.vpc_id
  vpc_2nd   = module.prod_networking_2nd.vpc_id
}