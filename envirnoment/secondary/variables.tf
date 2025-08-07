
variable "project_name" {
  type        = string
  description = "Project name for resource naming"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "availability_zones_2nd" {
  type        = list(string)
  description = "Availability zones for the second region"
}
