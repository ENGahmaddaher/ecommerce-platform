output "zone_id" { value = data.aws_route53_zone.this.zone_id }
output "api_fqdn" { value = try(aws_route53_record.api[0].fqdn, null) }
output "static_fqdn" { value = try(aws_route53_record.static[0].fqdn, null) }
