data "aws_ssm_parameter" "db_username" {
  name = "/i2508dr/db/db_username"
}

data "aws_ssm_parameter" "db_password" {
  name = "/i2508dr/db/db_password"
  with_decryption = true
}

module "rds" {
  source            = "../../../modules/rds"
  name              = "${local.name_prefix}-rds"
  vpc_id            = var.vpc_id
  security_group_id = var.rds_security_group_id
  subnet_ids        = var.private_subnet_ids
  db_instance_class = var.db_instance_class
  db_name           = var.db_name
  db_username       = data.aws_ssm_parameter.db_username.value 
  db_password       = data.aws_ssm_parameter.db_password.value
}

module "ssm" {
  source                   = "../../../modules/ssm"
  db_primary_endpoint      = module.rds.rds_endpoint
  db_active_endpoint       = module.rds.rds_endpoint
  db_primary_endpoint_path = "/${var.project_name}/db/primary_endpoint"
  db_active_endpoint_path  = "/${var.project_name}/db/active_endpoint"
}

module "route53_record" {
  source = "../../../modules/route53_record"
  zone_id = var.route53_zone_id
  rds_endpoint = module.rds.rds_endpoint
  record_name = "db"
}