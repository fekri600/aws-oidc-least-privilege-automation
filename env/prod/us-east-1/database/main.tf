

module "rds" {
  source            = "../../../../modules/rds"
  name              = "${var.name_prefix}-rds"
  vpc_id            = var.vpc_id
  security_group_id = var.rds_security_group_id
  db_subnet_group   = var.db_subnet_group_name
  db_instance_class = var.db_instance_class
  db_name           = var.db_name
  db_username       = var.db_username
  db_password       = var.db_password
}

module "route53_record" {
  source       = "../../../../modules/route53-record"
  zone_id      = var.route53_zone_id
  rds_endpoint = module.rds.rds_endpoint
  record_name  = "db"
}
