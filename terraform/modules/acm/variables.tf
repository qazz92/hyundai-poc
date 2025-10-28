# ACM Module Variables

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "region_name" {
  description = "Region name for resource naming"
  type        = string
}

variable "domain_name" {
  description = "Primary domain name for the certificate"
  type        = string
}

variable "subject_alternative_names" {
  description = "Subject Alternative Names (SANs) for the certificate"
  type        = list(string)
  default     = []
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID for DNS validation"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
