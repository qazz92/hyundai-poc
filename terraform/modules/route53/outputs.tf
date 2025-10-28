# Route53 Module Outputs

output "hosted_zone_id" {
  description = "Hosted zone ID"
  value       = local.hosted_zone_id
}

output "hosted_zone_name_servers" {
  description = "Name servers for the hosted zone"
  value       = var.create_hosted_zone ? aws_route53_zone.main[0].name_servers : []
}

# output "seoul_record_fqdn" {
#   description = "Seoul record FQDN"
#   value       = aws_route53_record.seoul.fqdn
# }

# output "us_east_record_fqdn" {
#   description = "US-East record FQDN"
#   value       = aws_route53_record.us_east.fqdn
# }

# output "us_west_record_fqdn" {
#   description = "US-West record FQDN"
#   value       = aws_route53_record.us_west.fqdn
# }

# output "cloudfront_record_fqdn" {
#   description = "CloudFront record FQDN"
#   value       = aws_route53_record.cloudfront.fqdn
# }

output "health_check_ids" {
  description = "Map of health check IDs"
  value = {
    seoul   = aws_route53_health_check.seoul.id
    us_east = aws_route53_health_check.us_east.id
    us_west = aws_route53_health_check.us_west.id
  }
}

output "domain_name" {
  description = "Domain name for the hosted zone"
  value       = var.domain_name
}
