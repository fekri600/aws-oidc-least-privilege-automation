module "ssm" {
  source                   = "../../../modules/ssm"
  db_primary_endpoint      = module.rds.rds_endpoint
  db_active_endpoint       = module.rds.rds_endpoint
  db_primary_endpoint_path = "/${var.zone_name}/db/primary_endpoint"
  db_active_endpoint_path  = "/${var.zone_name}/db/active_endpoint"
}