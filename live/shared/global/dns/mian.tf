module "route53_zone" {
  source       = "../../../modules/route53_zone"
  zone_name    = "fekri.ca"
  vpc_ids      = [var.vpc_1st, var.vpc_2nd]
}