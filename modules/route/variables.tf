variable "name" {
  type        = string
  description = "Prefix name for all resources in this network"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "gateway_id" {
  type        = string
  description = "Gateway ID"
}