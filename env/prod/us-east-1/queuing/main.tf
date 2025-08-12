module "sns" {
  source             = "../../../../modules/sns"
  name               = "${var.name_prefix}-lfn-fail-sns-tpc"
  email_subscription = var.email_subscription
}
