# Get current account information

module "backend-bucket" {
  source            = "./modules/backend-bucket"
  state_bucket_name = "${module.repo-param.repo_name}-state-${random_id.bucket_suffix.hex}"
}

module "asw-data" {
  source = "./data/asw-data"
}
module "repo-param" {
  source = "./data/repo-data"
}
module "oidc" {
  source = "./modules/oidc"

  # Pass backend-bucket output as input
  state_bucket_name = module.backend-bucket.bucket_name

  # Pass remaining variables from bootstrap
  iam_role_name        = var.iam_role_name
  iam_policy_name      = var.iam_policy_name
  oidc_url             = var.oidc_url
  oidc_client_id_list  = var.oidc_client_id_list
  oidc_thumbprint_list = var.oidc_thumbprint_list
  branch               = "main"
  account_id           = module.asw-data.account_id
  repo_owner           = module.repo-param.repo_owner
  repo_name            = module.repo-param.repo_name 
}

# module "explorer" {
#   source = "./modules/explorer"
  
# }

module "cloudtrail" {
  source = "./modules/couldtrail"
}

module "cloudtrail-lack" {
  source = "./modules/cloudtrail-lack"
}







