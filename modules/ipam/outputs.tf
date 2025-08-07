output "vpc_cidr" {
  value = data.external.ipam_vpc.result["cidr"]
}

output "publics" {
  value = split(",", data.external.ipam.result.public_subnets)
}

output "privates" {
  value = split(",", data.external.ipam.result.private_subnets)
}