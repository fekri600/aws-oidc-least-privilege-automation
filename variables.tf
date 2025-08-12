variable "availability_zones_1st" {
  type        = list(string)
  description = "Availability zones"
}


variable "primary_region" {
  type        = string
  description = "Primary region"
}

variable "availability_zones_2nd" {
  type        = list(string)
  description = "Availability zones"
}

variable "secondary_region" {
  type        = string
  description = "Secondary region"
}

variable "project_name" {
  type        = string
  description = "Project name"
}


variable "email_subscription" {
  type        = string
  description = "Email subscription"
}
variable "db_username" {
  type        = string
  description = "DB username"
}

variable "db_password" {
  type        = string
  description = "DB password"
  sensitive   = true
}

variable "db_name" {
  type        = string
  description = "DB name"
}
variable "db_instance_class" {
  type        = string
  description = "DB instance class"
}

variable "zone_name" {
  type        = string
  description = "Zone name"
}

variable "rds_snapshot_code_hash" {
  type        = string
  description = "RDS snapshot code hash"
}

variable "rds_failover_code_hash" {
  type        = string
  description = "RDS failover code hash"
}

variable "rds_snapshot_s3_key" {
  type        = string
  description = "RDS snapshot S3 key"
}

variable "rds_failover_s3_key" {
  type        = string
  description = "RDS failover S3 key"
} 

