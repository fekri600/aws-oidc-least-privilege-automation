module "ssm" {
  source                   = "../../../../modules/ssm"
  db_primary_endpoint      = var.db_primary_endpoint
  db_active_endpoint       = var.db_active_endpoint
  db_primary_endpoint_path = "/i2508dr/db/primary_endpoint"
  db_active_endpoint_path  = "/i2508dr/db/active_endpoint"
}