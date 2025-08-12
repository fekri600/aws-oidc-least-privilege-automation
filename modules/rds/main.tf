resource "aws_db_instance" "this" {
  allocated_storage   = 20
  engine              = "mysql"
  engine_version      = "8.0"
  instance_class      = var.db_instance_class
  db_name             = var.db_name
  username            = var.db_username
  password            = var.db_password
  skip_final_snapshot = true
  deletion_protection = false
  multi_az            = true

  db_subnet_group_name   = var.db_subnet_group
  vpc_security_group_ids = [var.security_group_id]

  # Backup retention for snapshot creation
  backup_retention_period = 7

  publicly_accessible = false

  tags = {
    Name = "${var.name}"
  }
}
