output "vpc_cidr" { value = local.vpc_result.cidr }
output "publics" {
  value = split(",", data.external.ipam_subnets.result.public_subnets)
}

output "privates" {
  value = split(",", data.external.ipam_subnets.result.private_subnets)
}