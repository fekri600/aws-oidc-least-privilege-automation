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

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Backup retention for snapshot creation
  backup_retention_period = 7

  publicly_accessible = false

  tags = {
    Name = "${var.name}"
  }
}
