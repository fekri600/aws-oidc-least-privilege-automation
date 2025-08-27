variable "name_prefix" {
  type        = string
  description = "Prefix name for all resources in this network"
}

variable "step_functions_arn" {
  type        = string
  description = "Step Functions ARN"
}

variable "step_functions_role_arn" {
  type        = string
  description = "Step Functions role ARN"
}

variable "db_instance_id" {
  type        = string
  description = "DB instance ID"
}