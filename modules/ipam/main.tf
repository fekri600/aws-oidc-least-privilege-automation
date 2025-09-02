data "external" "ipam_vpc" {
  program = ["python3", "${abspath(path.module)}/ipam_provider.py"]
  query = {
    resource_type = "vpc"
    env           = var.environment
    vpc_name      = var.vpc_name
  }
}

locals {
  vpc_result = data.external.ipam_vpc.result
}

# Force dependency by using a trigger that depends on VPC result
resource "null_resource" "vpc_allocated" {
  triggers = {
    vpc_cidr = data.external.ipam_vpc.result.cidr
  }
}

data "external" "ipam_subnets" {
  program = ["python3", "${abspath(path.module)}/ipam_provider.py"]
  query = {
    resource_type = "subnet"
    env           = var.environment
    vpc_name      = var.vpc_name
    public_count  = var.public_subnets_count
    private_count = var.private_subnets_count
  }
  depends_on = [null_resource.vpc_allocated]
}

