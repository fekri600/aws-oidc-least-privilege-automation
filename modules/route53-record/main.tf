resource "aws_route53_record" "rds_dns" {
  zone_id = var.zone_id
  name    = var.record_name
  type    = "CNAME"
  ttl     = 60
  records = [var.rds_endpoint]
}
