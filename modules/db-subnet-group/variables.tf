variable "name" {
  type        = string
  description = "DB subnet group name"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs"
}