variable "environment" {
  type        = string
  description = "Environment"
}

variable "project_name" {
  type        = string
  description = "Project name"
}

variable "db_username" {
  type        = string
  description = "Master username for RDS"
}

variable "db_password" {
  type        = string
  description = "Master password for RDS"
  sensitive   = true
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

variable "availability_zones_1st" {
  type        = list(string)
  description = "Availability zones for the first region"
}





