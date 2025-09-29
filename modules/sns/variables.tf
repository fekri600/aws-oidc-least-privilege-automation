variable "name" {
  type        = string
  description = "Prefix name for all resources in this network"
}

variable "email_subscription" {
  type        = string
  default     = ""
  description = "Email address to receive RDS backup notifications (optional)"
}