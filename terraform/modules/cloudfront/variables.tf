# CloudFront Module Variables

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "domain_name" {
  description = "Primary domain name (e.g., hyundai.alwaysummer.dev)"
  type        = string
  default     = ""
}

variable "certificate_arn" {
  description = "ACM certificate ARN for CloudFront (must be in us-east-1)"
  type        = string
  default     = ""
}

variable "seoul_alb_dns_name" {
  description = "Seoul ALB DNS name"
  type        = string
}

variable "us_east_alb_dns_name" {
  description = "US-East ALB DNS name"
  type        = string
}

variable "us_west_alb_dns_name" {
  description = "US-West ALB DNS name"
  type        = string
}

variable "price_class" {
  description = "CloudFront distribution price class"
  type        = string
  default     = "PriceClass_All"
}

variable "default_ttl" {
  description = "Default TTL for cached objects in seconds"
  type        = number
  default     = 86400 # 1 day
}

variable "min_ttl" {
  description = "Minimum TTL for cached objects in seconds"
  type        = number
  default     = 0
}

variable "max_ttl" {
  description = "Maximum TTL for cached objects in seconds"
  type        = number
  default     = 31536000 # 1 year
}

variable "enable_compression" {
  description = "Enable Gzip and Brotli compression"
  type        = bool
  default     = true
}

variable "enable_ipv6" {
  description = "Enable IPv6 for CloudFront distribution"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
