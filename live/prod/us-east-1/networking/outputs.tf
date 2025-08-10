output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Subnet IDs"
  value       = [module.subnet_private_az_1.subnet_id, module.subnet_private_az_2.subnet_id]
}





