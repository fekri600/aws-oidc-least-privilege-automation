

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "availability_zones" {
  type        = list(string)
  description = "Availability zones"
}

