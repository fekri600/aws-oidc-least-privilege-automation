variable "environment" {
  type        = string
  description = "Environment"
}

variable "project_name" {
  type        = string
  description = "Project name"
}

variable "availability_zones" {
  type        = list(string)
  description = "Availability zones"
}

