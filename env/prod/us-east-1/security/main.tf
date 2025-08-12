
module "rds_sg" {
  source      = "../../../../modules/security-group"
  name        = "${var.name_prefix}-rds-sg"
  description = "RDS SG allowing Lambda access"
  vpc_id      = var.vpc_id

  ingress_rules = [
    #{ from_port = 3306, to_port = 3306, protocol = "tcp", source_sg_id = module.app.security_group_id }
  ]
  egress_rules = [
    { from_port = 0, to_port = 0, protocol = "-1", source_sg_id = "", cidr_blocks = ["0.0.0.0/0"] }
  ]
}
