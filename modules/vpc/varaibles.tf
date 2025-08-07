variable "name" {
  type        = string
  description = "Prefix name for all resources in this network"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
}