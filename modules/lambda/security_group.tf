resource "aws_security_group" "lambda" {
  name        = "${var.function_name}-sg"
  description = "Lambda SG for VPC access"
  vpc_id      = var.vpc_id

  # No ingress: Lambda initiates outbound traffic only
  ingress = []

  egress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.input_security_group_id]
  }
}
