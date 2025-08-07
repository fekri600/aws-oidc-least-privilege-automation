module "ipam" {
  source      = "../../modules/ipam"
  environment = var.environment
}

# VPC for Secondary Region
module "vpc" {
  source = "../../modules/vpc"

  name     = "${local.name_prefix}-vpc"
  vpc_cidr = module.ipam.vpc_cidr


}

# Subnets for Secondary Region
module "subnet_public_az_1" {
  source = "../../modules/subnet"

  name                    = "${local.name_prefix}-subnet-pub-1"
  vpc_id                  = module.vpc.vpc_id
  cidr_block              = module.ipam.publics[0]
  availability_zone       = var.availability_zones_2nd[0]
  map_public_ip_on_launch = true
  route_table_id          = module.route_to_igw_az_1.route_table_id

}

module "subnet_public_az_2" {
  source = "../../modules/subnet"

  name                    = "${local.name_prefix}-subnet-pub-2"
  vpc_id                  = module.vpc.vpc_id
  cidr_block              = module.ipam.publics[1]
  availability_zone       = var.availability_zones_2nd[1]
  map_public_ip_on_launch = true
  route_table_id          = module.route_to_igw_az_2.route_table_id

}

module "subnet_private_az_1" {
  source = "../../modules/subnet"

  name                    = "${local.name_prefix}-subnet-priv-1"
  vpc_id                  = module.vpc.vpc_id
  cidr_block              = module.ipam.privates[0]
  availability_zone       = var.availability_zones_2nd[0]
  map_public_ip_on_launch = false
  route_table_id          = module.route_to_nat_gw_az_1.route_table_id

}

module "subnet_private_az_2" {
  source = "../../modules/subnet"

  name                    = "${local.name_prefix}-subnet-priv-2"
  vpc_id                  = module.vpc.vpc_id
  cidr_block              = module.ipam.privates[1]
  availability_zone       = var.availability_zones_2nd[1]
  map_public_ip_on_launch = false
  route_table_id          = module.route_to_nat_gw_az_2.route_table_id


}



# NAT Gateway for Secondary Region
module "nat_gw_az_1" {
  source = "../../modules/nat_gw"

  name      = "${local.name_prefix}-nat-gw"
  subnet_id = module.subnet_public_az_1.subnet_id


}

module "nat_gw_az_2" {
  source = "../../modules/nat_gw"

  name      = "${local.name_prefix}-nat-gw"
  subnet_id = module.subnet_public_az_2.subnet_id

}

# Route Tables for Secondary Region
module "route_to_igw_az_1" {
  source = "../../modules/route"

  name       = "${local.name_prefix}-rt-to-igw-az-1"
  vpc_id     = module.vpc.vpc_id
  gateway_id = module.vpc.igw_id

}

module "route_to_igw_az_2" {
  source = "../../modules/route"

  name       = "${local.name_prefix}-rt-to-igw-az-2"
  vpc_id     = module.vpc.vpc_id
  gateway_id = module.vpc.igw_id


}

module "route_to_nat_gw_az_1" {
  source = "../../modules/route"

  name       = "${local.name_prefix}-rt-to-nat-gw"
  vpc_id     = module.vpc.vpc_id
  gateway_id = module.nat_gw_az_1.nat_gateway_id

}

module "route_to_nat_gw_az_2" {
  source = "../../modules/route"

  name       = "${local.name_prefix}-rt-to-nat-gw-az-2"
  vpc_id     = module.vpc.vpc_id
  gateway_id = module.nat_gw_az_2.nat_gateway_id

}

module "iam" {
  source      = "../../modules/iam"
  environment = "secondary"
}







