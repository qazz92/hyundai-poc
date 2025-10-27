# CloudFront Module Outputs

# Frontend Distribution Outputs
output "frontend_distribution_id" {
  description = "Frontend CloudFront distribution ID"
  value       = aws_cloudfront_distribution.main.id
}

output "frontend_distribution_domain_name" {
  description = "Frontend CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "frontend_distribution_hosted_zone_id" {
  description = "Frontend CloudFront distribution hosted zone ID"
  value       = aws_cloudfront_distribution.main.hosted_zone_id
}

# API Distribution Outputs
output "api_distribution_id" {
  description = "API CloudFront distribution ID"
  value       = aws_cloudfront_distribution.api.id
}

output "api_distribution_domain_name" {
  description = "API CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.api.domain_name
}

output "api_distribution_hosted_zone_id" {
  description = "API CloudFront distribution hosted zone ID"
  value       = aws_cloudfront_distribution.api.hosted_zone_id
}

# WAF Output
output "waf_web_acl_id" {
  description = "WAF Web ACL ID"
  value       = aws_wafv2_web_acl.api.id
}

output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN"
  value       = aws_wafv2_web_acl.api.arn
}

# Lambda@Edge Output
output "geo_router_function_arn" {
  description = "Lambda@Edge Function ARN for geo routing"
  value       = aws_lambda_function.geo_router.qualified_arn
}

# Cache Policy IDs
output "static_cache_policy_id" {
  description = "Cache policy ID for static assets"
  value       = aws_cloudfront_cache_policy.static_assets.id
}

output "api_cache_policy_id" {
  description = "Cache policy ID for API calls"
  value       = aws_cloudfront_cache_policy.api.id
}

# Legacy output for backward compatibility
output "distribution_id" {
  description = "CloudFront distribution ID (frontend)"
  value       = aws_cloudfront_distribution.main.id
}

output "distribution_domain_name" {
  description = "CloudFront distribution domain name (frontend)"
  value       = aws_cloudfront_distribution.main.domain_name
}
