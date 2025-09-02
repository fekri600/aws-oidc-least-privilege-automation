module "route53_zone" {
  source    = "../../../../modules/route53-zone"
  zone_name = var.zone_name
  vpc_ids   = [var.vpc_2nd]
}