module "sns" {
  source = "../../../modules/sns"
  name   = "${local.name_prefix}-sns-topic"
  email_subscription = var.email_subscription
}
