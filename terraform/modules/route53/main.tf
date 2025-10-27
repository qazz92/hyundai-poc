# Route53 Module - DNS Routing and Health Checks
# Creates geolocation routing policies for global traffic distribution

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Create or use existing hosted zone
resource "aws_route53_zone" "main" {
  count = var.create_hosted_zone ? 1 : 0
  name  = var.domain_name

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-hosted-zone"
    }
  )
}

# Local variable to select the correct hosted zone ID
locals {
  hosted_zone_id = var.create_hosted_zone ? aws_route53_zone.main[0].zone_id : var.hosted_zone_id
}

# Health Check for Seoul ALB
resource "aws_route53_health_check" "seoul" {
  fqdn              = var.seoul_alb_dns_name
  port              = 80
  type              = "HTTP"
  resource_path     = var.health_check_path
  failure_threshold = 3
  request_interval  = var.health_check_interval

  tags = merge(
    var.tags,
    {
      Name   = "${var.project_name}-health-check-seoul"
      Region = "ap-northeast-2"
    }
  )
}

# Health Check for US-East ALB
resource "aws_route53_health_check" "us_east" {
  fqdn              = var.us_east_alb_dns_name
  port              = 80
  type              = "HTTP"
  resource_path     = var.health_check_path
  failure_threshold = 3
  request_interval  = var.health_check_interval

  tags = merge(
    var.tags,
    {
      Name   = "${var.project_name}-health-check-us-east"
      Region = "us-east-1"
    }
  )
}

# Health Check for US-West ALB
resource "aws_route53_health_check" "us_west" {
  fqdn              = var.us_west_alb_dns_name
  port              = 80
  type              = "HTTP"
  resource_path     = var.health_check_path
  failure_threshold = 3
  request_interval  = var.health_check_interval

  tags = merge(
    var.tags,
    {
      Name   = "${var.project_name}-health-check-us-west"
      Region = "us-west-2"
    }
  )
}

# Main Domain - Seoul Regional Record (Asia geolocation)
resource "aws_route53_record" "main_seoul" {
  zone_id = local.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.seoul_alb_dns_name
    zone_id                = var.seoul_alb_zone_id
    evaluate_target_health = true
  }

  set_identifier  = "seoul-alb"
  health_check_id = aws_route53_health_check.seoul.id

  geolocation_routing_policy {
    continent = "AS"
  }
}

# Main Domain - US Record (North America geolocation)
resource "aws_route53_record" "main_us" {
  zone_id = local.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.us_east_alb_dns_name
    zone_id                = var.us_east_alb_zone_id
    evaluate_target_health = true
  }

  set_identifier  = "us-alb"
  health_check_id = aws_route53_health_check.us_east.id

  geolocation_routing_policy {
    continent = "NA"
  }
}

# Main Domain - Europe Record (for European traffic)
resource "aws_route53_record" "main_europe" {
  zone_id = local.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.us_east_alb_dns_name
    zone_id                = var.us_east_alb_zone_id
    evaluate_target_health = true
  }

  set_identifier  = "europe-alb"
  health_check_id = aws_route53_health_check.us_east.id

  geolocation_routing_policy {
    continent = "EU"
  }
}

# Main Domain - South America Record
resource "aws_route53_record" "main_sa" {
  zone_id = local.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.us_east_alb_dns_name
    zone_id                = var.us_east_alb_zone_id
    evaluate_target_health = true
  }

  set_identifier  = "sa-alb"
  health_check_id = aws_route53_health_check.us_east.id

  geolocation_routing_policy {
    continent = "SA"
  }
}

# Main Domain - Oceania Record
resource "aws_route53_record" "main_oc" {
  zone_id = local.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.us_west_alb_dns_name
    zone_id                = var.us_west_alb_zone_id
    evaluate_target_health = true
  }

  set_identifier  = "oc-alb"
  health_check_id = aws_route53_health_check.us_west.id

  geolocation_routing_policy {
    continent = "OC"
  }
}

# Main Domain - Africa Record
resource "aws_route53_record" "main_af" {
  zone_id = local.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.us_east_alb_dns_name
    zone_id                = var.us_east_alb_zone_id
    evaluate_target_health = true
  }

  set_identifier  = "af-alb"
  health_check_id = aws_route53_health_check.us_east.id

  geolocation_routing_policy {
    continent = "AF"
  }
}

# Seoul Regional Subdomain Record
resource "aws_route53_record" "seoul" {
  zone_id = local.hosted_zone_id
  name    = "seoul.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.seoul_alb_dns_name
    zone_id                = var.seoul_alb_zone_id
    evaluate_target_health = true
  }
}

# US-East Regional Subdomain Record
resource "aws_route53_record" "us_east" {
  zone_id = local.hosted_zone_id
  name    = "us-east.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.us_east_alb_dns_name
    zone_id                = var.us_east_alb_zone_id
    evaluate_target_health = true
  }
}

# US-West Regional Subdomain Record
resource "aws_route53_record" "us_west" {
  zone_id = local.hosted_zone_id
  name    = "us-west.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.us_west_alb_dns_name
    zone_id                = var.us_west_alb_zone_id
    evaluate_target_health = true
  }
}

# Main API Record (via CloudFront with WAF)
resource "aws_route53_record" "api" {
  zone_id = local.hosted_zone_id
  name    = "api.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.cloudfront_api_domain_name
    zone_id                = var.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}

# Direct API Access (for POC testing and latency measurement)
resource "aws_route53_record" "api_direct_seoul" {
  zone_id = local.hosted_zone_id
  name    = "api-direct-seoul.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.seoul_alb_dns_name
    zone_id                = var.seoul_alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "api_direct_us_east" {
  zone_id = local.hosted_zone_id
  name    = "api-direct-us-east.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.us_east_alb_dns_name
    zone_id                = var.us_east_alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "api_direct_us_west" {
  zone_id = local.hosted_zone_id
  name    = "api-direct-us-west.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.us_west_alb_dns_name
    zone_id                = var.us_west_alb_zone_id
    evaluate_target_health = true
  }
}

# CloudFront Record for www subdomain (global distribution)
resource "aws_route53_record" "cloudfront" {
  zone_id = local.hosted_zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = var.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}

# Root domain record pointing to CloudFront (optional)
resource "aws_route53_record" "root" {
  zone_id = local.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = var.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}
