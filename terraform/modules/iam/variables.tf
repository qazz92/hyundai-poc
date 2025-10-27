# IAM Module Variables

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "region_name" {
  description = "Region name for resource naming (seoul, us_east, us_west)"
  type        = string
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
