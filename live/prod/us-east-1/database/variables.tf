variable "vpc_id" {
  type = string
}

variable "rds_security_group_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "db_instance_class" {
  type = string
}

variable "db_name" {
  type = string
}   

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}