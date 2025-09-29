variable "name_prefix" {
  type        = string
  description = "Name prefix"
}

# availability_zones variable removed - now using data source

variable "environment" {
  type = string
}