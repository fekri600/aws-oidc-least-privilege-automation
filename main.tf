module "prod_compute_1st" {
  source = "./live/prod/us-east-1/compute"
  project_name = var.project_name
  environment = "prod"
  db_name = var.db_name
  step_functions_role_arn = module.iam.step_functions_role_arn
  lambda_snapshot_role_arn = module.compute_1st.lambda_snapshot_role_arn
  lambda_failover_role_arn = module.compute_1st.lambda_failover_role_arn
  db_instance_id = module.database_1st.db_instance_id
  db_instance_class = module.database_1st.db_instance_class
  db_subnet_group_name_2nd = module.networking_2nd.db_subnet_group_name_2nd
  route53_zone_id = module.dns_zone.route53_zone_id
  primary_endpoint_name = module.database_1st.db_primary_endpoint
  active_endpoint_name = module.database_1st.db_active_endpoint
  db_dns_record_name = module.dns_zone.db_dns_record_name
  sns_topic_arn = module.sns.sns_topic_arn
  artifacts_bucket_name = module.storage.artifacts_bucket_name
  snapshot_code_hash = module.compute_1st.snapshot_code_hash
  failover_code_hash = module.compute_1st.failover_code_hash
}

module "prod_database_1st" {
  source = "./live/prod/us-east-1/database"
  project_name = var.project_name
  environment = "prod"
  db_name = var.db_name
  db_instance_class = var.db_instance_class
  vpc_id = module.networking_2nd.vpc_id
  private_subnet_ids = module.networking_2nd.private_subnet_ids
  rds_security_group_id = module.security_1st.rds_security_group_id
  project_name = var.project_name
}

module "prod_security_1st`" {
  source = "./live/shared/global/security"
  vpc_id = module.networking_2nd.vpc_id
  private_subnet_ids = module.networking_2nd.private_subnet_ids
  rds_security_group_id = module.security.rds_security_group_id
}

module "prod_networking_1st" {
  source = "./live/prod/us-west-1/networking"
  environment = var.environment
  availability_zones = var.availability_zones
}

module "prod_networking_2nd" {
  source = "./live/prod/us-east-1/networking"
  environment = var.environment
  project_name = var.project_name
  availability_zones = var.availability_zones
}


module "storage" {
  source = "./live/shared/global/storage"
  artifacts_bucket_name = module.storage.artifacts_bucket_name
}

module "ssm" {
  source = "./live/shared/global/ssm"
  db_primary_endpoint = module.database_1st.db_primary_endpoint
  db_active_endpoint = module.database_1st.db_active_endpoint
  db_primary_endpoint_path = "/${module.database_1st.project_name}/db/primary_endpoint"
  db_active_endpoint_path = "/${module.database_1st.project_name}/db/active_endpoint"
}
module "sns" {
  source = "./live/shared/global/sns"
  sns_topic_arn = module.sns.sns_topic_arn
}

module "dns_zone" {
  source = "./live/shared/global/dns"
  route53_zone_id = module.dns_zone.route53_zone_id
  rds_endpoint = module.database_1st.db_endpoint
  record_name = module.dns_zone.db_dns_record_name
}