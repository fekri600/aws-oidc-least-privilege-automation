module "ipam" {
  source             = "../../../../modules/ipam"
  environment        = var.environment
  vpc_name           = "${var.name_prefix}-vpc"
  public_subnets_count = length(var.availability_zones)
  private_subnets_count = length(var.availability_zones)
}
# VPC for Primary Region
module "vpc" {
  source   = "../../../../modules/vpc"
  name     = "${var.name_prefix}-vpc"
  vpc_cidr = module.ipam.vpc_cidr
}

# Private subnet in AZ 1
module "subnet_private_az_1" {
  source                  = "../../../../modules/subnet"
  name                    = "${var.name_prefix}-subnet-priv-1"
  vpc_id                  = module.vpc.vpc_id
  cidr_block              = module.ipam.privates[0]
  availability_zone       = var.availability_zones[0]
  map_public_ip_on_launch = false
}

# Private subnet in AZ 2
module "subnet_private_az_2" {
  source                  = "../../../../modules/subnet"
  name                    = "${var.name_prefix}-subnet-priv-2"
  vpc_id                  = module.vpc.vpc_id
  cidr_block              = module.ipam.privates[1]
  availability_zone       = var.availability_zones[1]
  map_public_ip_on_launch = false
}


module "db_subnet_group" {
  source     = "../../../../modules/db-subnet-group"
  name       = "${var.name_prefix}-db-subnet-group"
  subnet_ids = [module.subnet_private_az_1.subnet_id, module.subnet_private_az_2.subnet_id]
}

