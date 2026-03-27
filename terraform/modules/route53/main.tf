resource "aws_route53_zone" "this" {
  count = var.create_zone ? 1 : 0
  name  = var.domain_name
  tags  = merge(var.tags, { Name = var.domain_name })
}

data "aws_route53_zone" "existing" {
  count = !var.create_zone && var.domain_name != "" ? 1 : 0
  name  = var.domain_name
}
