data "aws_route53_zone" "this" {
  name         = var.domain_name
  private_zone = false
}

resource "aws_route53_record" "api" {
  count   = var.api_alb_dns_name != "" ? 1 : 0
  zone_id = data.aws_route53_zone.this.zone_id
  name    = "${var.api_subdomain}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.api_alb_dns_name
    zone_id                = var.api_alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "static" {
  count   = var.static_cloudfront_domain_name != "" ? 1 : 0
  zone_id = data.aws_route53_zone.this.zone_id
  name    = "${var.static_subdomain}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.static_cloudfront_domain_name
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}
