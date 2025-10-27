# Route53 Module Variables

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "domain_name" {
  description = "Primary domain name for hosted zone (e.g., hyundai-poc.com)"
  type        = string
}

variable "create_hosted_zone" {
  description = "Whether to create a new hosted zone (false if using existing domain)"
  type        = bool
  default     = false
}

variable "hosted_zone_id" {
  description = "Existing hosted zone ID (required if create_hosted_zone is false)"
  type        = string
  default     = ""
}

variable "seoul_alb_dns_name" {
  description = "Seoul ALB DNS name"
  type        = string
}

variable "seoul_alb_zone_id" {
  description = "Seoul ALB Route53 zone ID"
  type        = string
}

variable "us_east_alb_dns_name" {
  description = "US-East ALB DNS name"
  type        = string
}

variable "us_east_alb_zone_id" {
  description = "US-East ALB Route53 zone ID"
  type        = string
}

variable "us_west_alb_dns_name" {
  description = "US-West ALB DNS name"
  type        = string
}

variable "us_west_alb_zone_id" {
  description = "US-West ALB Route53 zone ID"
  type        = string
}

variable "cloudfront_domain_name" {
  description = "CloudFront distribution domain name (frontend)"
  type        = string
  default     = ""
}

variable "cloudfront_api_domain_name" {
  description = "CloudFront API distribution domain name"
  type        = string
  default     = ""
}

variable "cloudfront_hosted_zone_id" {
  description = "CloudFront hosted zone ID (Z2FDTNDATAQYW2 for all distributions)"
  type        = string
  default     = "Z2FDTNDATAQYW2"
}

variable "health_check_path" {
  description = "Health check path for ALB endpoints"
  type        = string
  default     = "/health"
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
}

variable "ttl" {
  description = "DNS record TTL in seconds (lower for faster failover)"
  type        = number
  default     = 60
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
