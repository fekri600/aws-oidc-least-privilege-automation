variable "environment" {
  type        = string
  description = "Environment"
}

variable "project_name" {
  type        = string
  description = "Project name"
}


variable "db_name" {
  type        = string
  description = "Initial database name"
}
variable "db_instance_class" {
  type        = string
  description = "RDS instance type"
}

variable "email_subscription" {
  type        = string
  description = "Email address for SNS notifications"
  default     = ""
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}
variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs"
}

variable "route53_zone_id" {
  type        = string
  description = "Route53 zone ID"
}

variable "lambda_snapshot_role_arn" {
  type        = string
  description = "Lambda snapshot role ARN"
}
variable "lambda_failover_role_arn" {
  type        = string
  description = "Lambda failover role ARN"
}

variable "step_functions_role_arn" {
  type        = string
  description = "Step Functions role ARN"
}


