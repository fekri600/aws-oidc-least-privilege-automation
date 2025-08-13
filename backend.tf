terraform {
  backend "s3" {
    bucket         = ""
    key            = "envs/terraform.tfstate"
    region         = ""
    dynamodb_table = ""
    encrypt        = true
  }
}
