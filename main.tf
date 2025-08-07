module "primary" {
  source                 = "./envirnoment/primary"
  environment            = "primary"
  project_name           = var.project_name
  availability_zones_1st = var.availability_zones_1st
  db_instance_class      = var.db_instance_class
  db_username            = module.ssm.db_username
  db_password            = module.ssm.db_password
  db_name                = var.db_name
  email_subscription     = var.email_subscription
  providers = {
    aws = aws.primary
  }

}

module "secondary" {
  source                 = "./envirnoment/secondary"
  environment            = "secondary"
  project_name           = var.project_name
  availability_zones_2nd = var.availability_zones_2nd
  providers = {
    aws = aws.secondary
  }

}

module "route53_zone_record" {
  source       = "./modules/route53"
  zone_name    = "fekri.ca"
  vpc_ids      = [module.primary.vpc_id, module.secondary.vpc_id]
  rds_endpoint = module.primary.db_primary_endpoint
}


resource "null_resource" "package_lambda" {
  provisioner "local-exec" {
    command = "zip -j lambda_src/snapshot_lambda.zip lambda_src/snapshot_lambda.py"
  }
}
