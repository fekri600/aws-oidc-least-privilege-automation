variable "name_prefix" {
  type        = string
  description = "Name prefix"
}

variable "availability_zones" {
  type        = list(string)
  description = "Availability zones"
}

variable "environment" {
  type = string
}