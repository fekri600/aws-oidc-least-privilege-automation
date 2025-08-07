resource "aws_route53_zone" "this" {
  name    = var.zone_name
  comment = "Private hosted zone for RDS failover"
  vpc {
    vpc_id = var.vpc_ids[0]
  }

  dynamic "vpc" {
    for_each = slice(var.vpc_ids, 1, length(var.vpc_ids))
    content {
      vpc_id = vpc.value
    }
  }
}
