

module "rds_sg" {
  source      = "../../../modules/security-group"
  name        = "rds"
  description = "RDS SG allowing Lambda access"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = [
    #{ from_port = 3306, to_port = 3306, protocol = "tcp", source_sg_id = module.app.security_group_id }
  ]
  egress_rules = [
    { from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }
  ]
}
