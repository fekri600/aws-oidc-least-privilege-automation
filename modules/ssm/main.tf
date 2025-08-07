

resource "aws_ssm_parameter" "db_primary_endpoint" {
  name      = var.db_primary_endpoint_path
  type      = "String"
  value     = var.db_primary_endpoint
  overwrite = true
}

resource "aws_ssm_parameter" "db_active_endpoint" {
  name      = var.db_active_endpoint_path
  type      = "String"
  value     = var.db_active_endpoint
  overwrite = true
}