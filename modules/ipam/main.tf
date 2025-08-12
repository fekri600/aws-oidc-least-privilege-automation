data "external" "ipam_vpc" {
  program = ["python3", "${abspath(path.module)}/ipam_provider.py"]

  query = {
    resource_type = "vpc"
    base_cidr     = "10.0.0.0"
    prefix        = 16
    env           = var.environment
  }
}




data "external" "ipam" {
  program = ["python3", "${abspath(path.module)}/ipam_provider.py"]

  query = {
    resource_type = "subnet"
    env           = var.environment
    vpc_cidr      = data.external.ipam_vpc.result["cidr"]
    public_count  = length(var.availability_zones)
    private_count = length(var.availability_zones)
    prefix        = 24
  }
}





