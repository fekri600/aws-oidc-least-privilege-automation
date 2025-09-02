resource "aws_route53_zone" "private" {
  name    = var.zone_name
  comment = "Private hosted zone for ${var.zone_name}"

  vpc {
    vpc_id = var.vpc_id
  }
}