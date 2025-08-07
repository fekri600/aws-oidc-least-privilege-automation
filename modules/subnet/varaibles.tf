variable "name" {
  type        = string
  description = "Prefix name for all resources in this network"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "cidr_block" { type = string }
variable "availability_zone" { type = string }
variable "map_public_ip_on_launch" { type = bool }
variable "route_table_id" { type = string } 