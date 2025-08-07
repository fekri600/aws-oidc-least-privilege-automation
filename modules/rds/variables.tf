variable "name" {
  type        = string
  description = "RDS name"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "lambda_sg_id" {
  type        = string
  description = "Lambda Security Group ID"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs"
}

variable "db_instance_class" {
  type        = string
  description = "RDS instance class"
}

variable "db_name" {
  type        = string
  description = "RDS database name"
}

variable "db_username" {
  type        = string
  description = "RDS database username"
}

variable "db_password" {
  type        = string
  description = "RDS database password"
}



