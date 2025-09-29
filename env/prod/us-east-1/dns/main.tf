module "route53_zone" {
  source    = "../../../../modules/route53-zone"
  zone_name = var.zone_name
  vpc_id    = var.vpc_1st
}