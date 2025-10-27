# Root Terraform Outputs

# VPC Outputs
output "vpc_ids" {
  description = "VPC IDs by region"
  value = {
    seoul   = module.vpc_seoul.vpc_id
    us_east = module.vpc_us_east.vpc_id
    us_west = module.vpc_us_west.vpc_id
  }
}

# ALB Outputs
output "alb_dns_names" {
  description = "ALB DNS names by region"
  value = {
    seoul   = module.alb_seoul.alb_dns_name
    us_east = module.alb_us_east.alb_dns_name
    us_west = module.alb_us_west.alb_dns_name
  }
}

# Aurora Outputs
output "aurora_endpoints" {
  description = "Aurora database endpoints"
  value = {
    global_cluster_id = module.aurora_us_east.global_cluster_id
    primary = {
      writer = module.aurora_us_east.writer_endpoint
      reader = module.aurora_us_east.reader_endpoint
    }
    seoul = {
      reader = module.aurora_seoul.reader_endpoint
    }
    us_west = {
      reader = module.aurora_us_west.reader_endpoint
    }
  }
  sensitive = true
}

# ECS Outputs
output "ecs_clusters" {
  description = "ECS cluster ARNs by region"
  value = {
    seoul   = module.ecs_seoul.cluster_arn
    us_east = module.ecs_us_east.cluster_arn
    us_west = module.ecs_us_west.cluster_arn
  }
}

# Regional Endpoints
output "regional_endpoints" {
  description = "Regional application endpoints for testing"
  value = {
    seoul = {
      frontend = "http://${module.alb_seoul.alb_dns_name}"
      backend  = "http://${module.alb_seoul.alb_dns_name}/health"
    }
    us_east = {
      frontend = "http://${module.alb_us_east.alb_dns_name}"
      backend  = "http://${module.alb_us_east.alb_dns_name}/health"
    }
    us_west = {
      frontend = "http://${module.alb_us_west.alb_dns_name}"
      backend  = "http://${module.alb_us_west.alb_dns_name}/health"
    }
  }
}

# Route53 Outputs
output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = module.route53.hosted_zone_id
}

output "route53_nameservers" {
  description = "Route53 hosted zone name servers"
  value       = module.route53.hosted_zone_name_servers
}

# CloudFront Outputs
output "cloudfront_frontend_distribution_id" {
  description = "CloudFront frontend distribution ID"
  value       = module.cloudfront.frontend_distribution_id
}

output "cloudfront_frontend_domain_name" {
  description = "CloudFront frontend distribution domain name"
  value       = module.cloudfront.frontend_distribution_domain_name
}

output "cloudfront_api_distribution_id" {
  description = "CloudFront API distribution ID"
  value       = module.cloudfront.api_distribution_id
}

output "cloudfront_api_domain_name" {
  description = "CloudFront API distribution domain name"
  value       = module.cloudfront.api_distribution_domain_name
}

output "cloudfront_waf_web_acl_arn" {
  description = "WAF Web ACL ARN for API CloudFront"
  value       = module.cloudfront.waf_web_acl_arn
}

# Monitoring Outputs
output "cloudwatch_dashboard_name" {
  description = "CloudWatch dashboard name"
  value       = module.monitoring.dashboard_name
}

output "kinesis_firehose_name" {
  description = "Kinesis Data Firehose delivery stream name"
  value       = module.monitoring.firehose_delivery_stream_name
}
