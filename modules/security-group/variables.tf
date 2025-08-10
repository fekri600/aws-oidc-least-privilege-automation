variable "name" {
  type        = string
  description = "The name of the security group"
}

variable "vpc_id" {
  type        = string
  description = "The ID of the VPC"
}

variable "ingress_rules" {
  type        = list(object({
    from_port = number
    to_port = number
    protocol = string
    source_sg_id = string
    cidr_blocks = list(string)
  }))
  description = "List of ingress rules"
}

variable "egress_rules" {
  type        = list(object({
    from_port = number
    to_port = number
    protocol = string
    source_sg_id = string
    cidr_blocks = list(string)
  }))
  description = "List of egress rules"
}

variable "description" {
  type        = string
  description = "The description of the security group"
}