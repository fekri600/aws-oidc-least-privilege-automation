data "external" "ipam_vpc" {
  program = ["python3", "ipam_provider.py"]

  query = {
    resource_type = "vpc"
    base_cidr     = var.network.network_cidr
    prefix        = 16
    env           = var.environment
  }
}




data "external" "ipam" {
  program = ["python3", "ipam_provider.py"]

  query = {
    resource_type = "subnet"
    env           = var.environment
    vpc_cidr      = data.external.ipam_vpc.result["cidr"]
    public_count  = length(var.network.availability_zones)
    private_count = length(var.network.availability_zones)
    prefix        = 24
  }
}





