# module "prod_us_east_1_network" {
#   source = "./env/prod/us-east-1/networking"
#   name_prefix = local.prefix.prod_us_east_1
#   environment = "prod"
# }

module "prod_us_east_1_dns" {
  source = "./env/prod/us-east-1/dns"
  vpc_1st = module.prod_us_east_1_network.vpc_id
  zone_name = "prod-us-east-1.i2509dr.com"
}

# module "prod_us_east_1_queue" {
#   source = "./env/prod/us-east-1/queuing"
#   name_prefix = local.prefix.prod_us_east_1
#   email_subscription = "admin@i2509dr.com"
# }

# module "prod_us_east_1_security" {
#   source = "./env/prod/us-east-1/security"
#   name_prefix = local.prefix.prod_us_east_1
#   vpc_id = module.prod_us_east_1_network.vpc_id
# }



# module "prod_us_west_1_network" {
#   source = "./env/prod/us-west-1/networking"
#   name_prefix = local.prefix.prod_us_west_1
#   environment = "prod" 

#   providers = {
#     aws = aws.secondary
#   }
# }


module "shared_storage" {
  source = "./env/shared/global/storage"
  name_prefix = local.prefix.shared 
}




