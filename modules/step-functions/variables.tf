variable "name" {
  type        = string
  description = "Prefix name for all resources in this network"
}

variable "role_arn" {
  type        = string
  description = "Role ARN"
}

variable "state_machine_definition" {
  type        = string
  description = "State machine definition"
}

variable "enable_logging" {
  type        = bool
  description = "Enable logging for the state machine"
  default     = false
}

variable "logging_level" {
  type        = string
  description = "Logging level"
  default     = "ALL"
}

variable "include_execution_data" {
  type        = bool
  description = "Include execution data"
  default     = true
}

variable "cloudwatch_log_group_name" {
  type        = string
  description = "Cloudwatch log group name"
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Tags"
}