variable "zone_name" {
  type        = string
  description = "Route53 zone name"
}

variable "vpc_ids" {
  type        = list(string)
  description = "VPC IDs"
}
variable "rds_endpoint" {
  type        = string
  description = "RDS endpoint"
}