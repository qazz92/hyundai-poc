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
    header_behavior = "allViewerAndWhitelistCloudFront"
    headers {
      items = ["CloudFront-Viewer-Country", "CloudFront-Viewer-Latitude", "CloudFront-Viewer-Longitude", "CloudFront-Viewer-Time-Zone"]
    }
  }

  query_strings_config {
    query_string_behavior = "all"
  }
}

# Response Headers Policy for CORS
resource "aws_cloudfront_response_headers_policy" "cors" {
  name    = "${var.project_name}-cors-policy"
  comment = "CORS policy for Next.js SSR"

  cors_config {
    access_control_allow_credentials = false

    access_control_allow_headers {
      items = ["*"]
    }

    access_control_allow_methods {
      items = ["GET", "HEAD", "OPTIONS", "PUT", "PATCH", "POST", "DELETE"]
    }

    access_control_allow_origins {
      items = ["*"]
    }

    access_control_max_age_sec = 600
    origin_override = true
  }
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = var.enable_ipv6
  comment             = "${var.project_name} Global Distribution"
  # Removed default_root_object for SSR - Next.js handles routing dynamically
  price_class         = var.price_class
  aliases             = var.domain_name != "" ? [var.domain_name] : []

  # Single Origin: US-East ALB (frontend served globally from one region)
  origin {
    domain_name = var.us_east_alb_dns_name
    origin_id   = "us-east-alb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Default Cache Behavior (SSR pages - NO CACHING for dynamic content)
  default_cache_behavior {
    allowed_methods             = ["GET", "HEAD", "OPTIONS"]
    cached_methods              = ["GET", "HEAD"]
    target_origin_id            = "us-east-alb"
    cache_policy_id             = aws_cloudfront_cache_policy.api.id  # Use no-cache policy for SSR
    origin_request_policy_id    = aws_cloudfront_origin_request_policy.api.id  # Forward all headers/cookies for SSR
    response_headers_policy_id  = aws_cloudfront_response_headers_policy.cors.id  # CORS headers
    viewer_protocol_policy      = "redirect-to-https"
    compress                    = var.enable_compression
    smooth_streaming            = false
    trusted_key_groups          = []
    trusted_signers             = []
  }

  # Ordered Cache Behavior: Static Assets (Next.js)
  ordered_cache_behavior {
    path_pattern               = "/_next/static/*"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "us-east-alb"
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
    target_origin_id           = "us-east-alb"
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
    target_origin_id           = "us-east-alb"
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
    target_origin_id           = "us-east-alb"
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
    target_origin_id           = "us-east-alb"
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
    target_origin_id           = "us-east-alb"
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

  # Viewer Certificate (custom domain with ACM certificate or default)
  viewer_certificate {
    acm_certificate_arn            = var.certificate_arn != "" ? var.certificate_arn : null
    cloudfront_default_certificate = var.certificate_arn == "" ? true : false
    minimum_protocol_version       = "TLSv1.2_2021"
    ssl_support_method             = var.certificate_arn != "" ? "sni-only" : null
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
  runtime       = "nodejs22.x"
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
  aliases         = var.domain_name != "" ? ["api.${var.domain_name}"] : []

  # Origin 1: Seoul ALB
  origin {
    domain_name = var.seoul_alb_dns_name
    origin_id   = "seoul-alb"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
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
      origin_protocol_policy = "https-only"
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
      origin_protocol_policy = "https-only"
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
    acm_certificate_arn            = var.certificate_arn != "" ? var.certificate_arn : null
    cloudfront_default_certificate = var.certificate_arn == "" ? true : false
    minimum_protocol_version       = "TLSv1.2_2021"
    ssl_support_method             = var.certificate_arn != "" ? "sni-only" : null
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-cloudfront-api"
    }
  )
}
