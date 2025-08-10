variable "db_instance_id" {
  type = string
}

variable "sns_topic_arn" {
  type = string
}

variable "db_subnet_group_name_2nd" {
  type = string
}
variable "lambda_snapshot_role_arn" {
  type = string
}

variable "step_functions_role_arn" {
  type = string
}
variable "lambda_failover_role_arn" {
  type = string
}
variable "route53_zone_id" {
  type = string
}
variable "db_dns_record_name" {
  type = string
}
variable "primary_endpoint_name" {
  type = string
}
variable "active_endpoint_name" {
  type = string
}

variable "db_instance_class" {
  type = string
}

variable "db_name" {
  type = string
}

variable "snapshot_code_hash" {
  type = string
}

variable "failover_code_hash" {
  type = string
}

variable "artifacts_bucket_name" {
  type = string
}
variable "project_name" {
  type = string
}
variable "environment" {
  type = string
}