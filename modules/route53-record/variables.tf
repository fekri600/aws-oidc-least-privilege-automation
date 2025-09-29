variable "zone_id" {
  type        = string
  description = "Route53 zone ID"
}

variable "rds_endpoint" {
  type        = string
  description = "RDS endpoint"
}

variable "record_name" {
  type        = string
  description = "Record name"
}