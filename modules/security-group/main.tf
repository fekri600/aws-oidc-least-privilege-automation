resource "aws_security_group" "this" {
  name        = var.name
  description = var.description
  vpc_id      = var.vpc_id
}

# Classify rules once
locals {
  ingress_cidr = [for r in var.ingress_rules : r if try(length(r.cidr_blocks) > 0, false)]
  ingress_sg   = [for r in var.ingress_rules : r if try(r.source_sg_id != null && r.source_sg_id != "", false)]

  egress_cidr  = [for r in var.egress_rules  : r if try(length(r.cidr_blocks) > 0, false)]
  egress_sg    = [for r in var.egress_rules  : r if try(r.source_sg_id != null && r.source_sg_id != "", false)]
}

# Ingress from CIDRs
resource "aws_security_group_rule" "ingress_cidr" {
  for_each          = { for i, r in local.ingress_cidr : i => r }
  type              = "ingress"
  security_group_id = aws_security_group.this.id
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = each.value.cidr_blocks
}

# Ingress from SGs
resource "aws_security_group_rule" "ingress_sg" {
  for_each                 = { for i, r in local.ingress_sg : i => r }
  type                     = "ingress"
  security_group_id        = aws_security_group.this.id
  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  protocol                 = each.value.protocol
  source_security_group_id = each.value.source_sg_id
}

# Egress to CIDRs
resource "aws_security_group_rule" "egress_cidr" {
  for_each          = { for i, r in local.egress_cidr : i => r }
  type              = "egress"
  security_group_id = aws_security_group.this.id
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = each.value.cidr_blocks
}

# Egress to SGs
resource "aws_security_group_rule" "egress_sg" {
  for_each                 = { for i, r in local.egress_sg : i => r }
  type                     = "egress"
  security_group_id        = aws_security_group.this.id
  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  protocol                 = each.value.protocol
  source_security_group_id = each.value.source_sg_id
}
