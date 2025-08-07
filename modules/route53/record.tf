resource "aws_route53_record" "rds_dns" {
  zone_id = aws_route53_zone.this.zone_id
  name    = aws_route53_zone.this.name
  type    = "CNAME"
  ttl     = 60
  records = [var.rds_endpoint]
}
