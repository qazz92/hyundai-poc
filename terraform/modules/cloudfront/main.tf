# CloudFront Module - Global CDN with Multi-Region Failover
# Creates CloudFront distribution with origin failover group

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

# Origin Access Control for CloudFront (modern replacement for OAI)
resource "aws_cloudfront_origin_access_control" "main" {
  name                              = "${var.project_name}-oac"
  description                       = "Origin Access Control for ${var.project_name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Cache Policy for Static Assets
resource "aws_cloudfront_cache_policy" "static_assets" {
  name        = "${var.project_name}-static-assets-policy"
  comment     = "Cache policy for static assets (Next.js)"
  default_ttl = var.default_ttl
  max_ttl     = var.max_ttl
  min_ttl     = var.min_ttl

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }

    headers_config {
      header_behavior = "none"
    }

    query_strings_config {
      query_string_behavior = "none"
    }

    enable_accept_encoding_gzip   = var.enable_compression
    enable_accept_encoding_brotli = var.enable_compression
  }
}

# Cache Policy for API Calls (no caching)
resource "aws_cloudfront_cache_policy" "api" {
  name        = "${var.project_name}-api-policy"
  comment     = "No-cache policy for API calls"
  default_ttl = 0
  max_ttl     = 0
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }

    headers_config {
      header_behavior = "none"
    }

    query_strings_config {
      query_string_behavior = "none"
    }

    enable_accept_encoding_gzip   = false
    enable_accept_encoding_brotli = false
  }
}

# Origin Request Policy for API Calls
resource "aws_cloudfront_origin_request_policy" "api" {
  name    = "${var.project_name}-api-origin-policy"
  comment = "Forward all headers and query strings for API calls"

  cookies_config {
    cookie_behavior = "all"
  }

  headers_config {
    header_behavior = "allViewer"
  }

  query_strings_config {
    query_string_behavior = "all"
  }
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = var.enable_ipv6
  comment             = "${var.project_name} Global Distribution"
  default_root_object = "index.html"
  price_class         = var.price_class

  # Primary Origin: Seoul ALB
  origin {
    domain_name = var.seoul_alb_dns_name
    origin_id   = "seoul-alb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Secondary Origin: US-East ALB
  origin {
    domain_name = var.us_east_alb_dns_name
    origin_id   = "us-east-alb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Tertiary Origin: US-West ALB
  origin {
    domain_name = var.us_west_alb_dns_name
    origin_id   = "us-west-alb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Origin Group with Failover
  origin_group {
    origin_id = "failover-group"

    failover_criteria {
      status_codes = [500, 502, 503, 504, 404]
    }

    member {
      origin_id = "seoul-alb"
    }

    member {
      origin_id = "us-east-alb"
    }
  }

  # Default Cache Behavior (API calls - use single origin for POST/PUT/DELETE support)
  default_cache_behavior {
    allowed_methods            = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "us-east-alb"
    cache_policy_id            = aws_cloudfront_cache_policy.api.id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.api.id
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = false
    smooth_streaming           = false
    trusted_key_groups         = []
    trusted_signers            = []
  }

  # Ordered Cache Behavior: Static Assets (Next.js)
  ordered_cache_behavior {
    path_pattern               = "/_next/static/*"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "failover-group"
    cache_policy_id            = aws_cloudfront_cache_policy.static_assets.id
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = var.enable_compression
    smooth_streaming           = false
    trusted_key_groups         = []
    trusted_signers            = []
  }

  # Ordered Cache Behavior: Public Static Files
  ordered_cache_behavior {
    path_pattern               = "/static/*"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "failover-group"
    cache_policy_id            = aws_cloudfront_cache_policy.static_assets.id
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = var.enable_compression
    smooth_streaming           = false
    trusted_key_groups         = []
    trusted_signers            = []
  }

  # Ordered Cache Behavior: Images - JPG
  ordered_cache_behavior {
    path_pattern               = "*.jpg"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "failover-group"
    cache_policy_id            = aws_cloudfront_cache_policy.static_assets.id
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = var.enable_compression
    smooth_streaming           = false
    trusted_key_groups         = []
    trusted_signers            = []
  }

  # Ordered Cache Behavior: Images - PNG
  ordered_cache_behavior {
    path_pattern               = "*.png"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "failover-group"
    cache_policy_id            = aws_cloudfront_cache_policy.static_assets.id
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = var.enable_compression
    smooth_streaming           = false
    trusted_key_groups         = []
    trusted_signers            = []
  }

  # Ordered Cache Behavior: Images - SVG
  ordered_cache_behavior {
    path_pattern               = "*.svg"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "failover-group"
    cache_policy_id            = aws_cloudfront_cache_policy.static_assets.id
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = var.enable_compression
    smooth_streaming           = false
    trusted_key_groups         = []
    trusted_signers            = []
  }

  # Ordered Cache Behavior: Images - ICO
  ordered_cache_behavior {
    path_pattern               = "*.ico"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "failover-group"
    cache_policy_id            = aws_cloudfront_cache_policy.static_assets.id
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = var.enable_compression
    smooth_streaming           = false
    trusted_key_groups         = []
    trusted_signers            = []
  }

  # Restrictions
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Viewer Certificate (default CloudFront certificate)
  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-cloudfront-frontend"
    }
  )
}

# ====================
# WAF for API CloudFront
# ====================

resource "aws_wafv2_web_acl" "api" {
  name  = "${var.project_name}-api-waf"
  scope = "CLOUDFRONT"  # Must be CLOUDFRONT for global distribution

  default_action {
    allow {}
  }

  # Rule 1: Rate limiting (2000 requests per 5 minutes per IP)
  rule {
    name     = "RateLimitRule"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  # Rule 2: AWS Managed Rules - Common Rule Set
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-common-rules"
      sampled_requests_enabled   = true
    }
  }

  # Rule 3: AWS Managed Rules - Known Bad Inputs
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-api-waf"
    sampled_requests_enabled   = true
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-api-waf"
    }
  )
}

# ====================
# Lambda@Edge for Geographic Origin Selection
# ====================

# IAM role for Lambda@Edge
resource "aws_iam_role" "lambda_edge" {
  name = "${var.project_name}-lambda-edge-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "lambda.amazonaws.com",
            "edgelambda.amazonaws.com"
          ]
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-lambda-edge-role"
    }
  )
}

# Attach basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_edge_basic" {
  role       = aws_iam_role.lambda_edge.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda function for origin request
# Note: Lambda@Edge must be created in us-east-1
resource "aws_lambda_function" "geo_router" {
  filename      = data.archive_file.lambda_edge.output_path
  function_name = "${var.project_name}-geo-router"
  role          = aws_iam_role.lambda_edge.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  publish       = true
  timeout       = 5

  source_code_hash = data.archive_file.lambda_edge.output_base64sha256

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-lambda-edge-geo-router"
    }
  )
}

# Create Lambda deployment package
data "archive_file" "lambda_edge" {
  type        = "zip"
  output_path = "${path.module}/lambda-edge.zip"

  source {
    content = templatefile("${path.module}/lambda-edge.js", {
      seoul_alb_dns_name   = var.seoul_alb_dns_name
      us_east_alb_dns_name = var.us_east_alb_dns_name
      us_west_alb_dns_name = var.us_west_alb_dns_name
    })
    filename = "index.js"
  }
}

# ====================
# API CloudFront Distribution
# ====================

resource "aws_cloudfront_distribution" "api" {
  enabled         = true
  is_ipv6_enabled = var.enable_ipv6
  comment         = "${var.project_name} API Distribution with WAF"
  price_class     = var.price_class
  web_acl_id      = aws_wafv2_web_acl.api.arn

  # Origin 1: Seoul ALB
  origin {
    domain_name = var.seoul_alb_dns_name
    origin_id   = "seoul-alb"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
    custom_header {
      name  = "X-CloudFront-Secret"
      value = "hyundai-poc-secret-2024"
    }
  }

  # Origin 2: US-East ALB
  origin {
    domain_name = var.us_east_alb_dns_name
    origin_id   = "us-east-alb"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
    custom_header {
      name  = "X-CloudFront-Secret"
      value = "hyundai-poc-secret-2024"
    }
  }

  # Origin 3: US-West ALB
  origin {
    domain_name = var.us_west_alb_dns_name
    origin_id   = "us-west-alb"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
    custom_header {
      name  = "X-CloudFront-Secret"
      value = "hyundai-poc-secret-2024"
    }
  }

  # Default Cache Behavior - NO CACHING for API
  # Geographic routing is handled by Lambda@Edge (origin-request)
  # Lambda@Edge dynamically selects the closest regional origin
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "us-east-alb"

    cache_policy_id          = aws_cloudfront_cache_policy.api.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.api.id
    viewer_protocol_policy   = "redirect-to-https"
    compress                 = false

    # Lambda@Edge for dynamic origin selection
    lambda_function_association {
      event_type   = "origin-request"
      lambda_arn   = aws_lambda_function.geo_router.qualified_arn
      include_body = false
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-cloudfront-api"
    }
  )
}
