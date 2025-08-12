variable "vpc_id" {
  type = string
}

variable "rds_security_group_id" {
  type = string
}

variable "db_instance_class" {
  type = string
}

variable "db_name" {
  type = string
}

variable "name_prefix" {
  type = string
}

variable "route53_zone_id" {
  type = string
}

variable "db_subnet_group_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type = string
}