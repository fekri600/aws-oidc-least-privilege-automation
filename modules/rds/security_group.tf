resource "aws_security_group" "rds" {
  name        = "${var.name}-rds-sg"
  description = "RDS SG allowing access from Lambda only"
  vpc_id      = var.vpc_id

  # Allow Lambda -> RDS on MySQL port
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.lambda_sg_id]
  }

}
