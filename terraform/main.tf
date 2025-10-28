# Hyundai Motors POC - Root Terraform Configuration
# Multi-region infrastructure deployment for Aurora Global Database and ECS Fargate

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Default Provider (uses US-East as primary region)
provider "aws" {
  region  = var.regions.us_east
  profile = "hyundai-poc"

  default_tags {
    tags = var.tags
  }
}

# Provider Configuration for Seoul (ap-northeast-2)
provider "aws" {
  alias   = "seoul"
  region  = var.regions.seoul
  profile = "hyundai-poc"

  default_tags {
    tags = var.tags
  }
}

# Provider Configuration for US-East (us-east-1) - Primary Region
provider "aws" {
  alias   = "us_east"
  region  = var.regions.us_east
  profile = "hyundai-poc"

  default_tags {
    tags = var.tags
  }
}

# Provider Configuration for US-West (us-west-2)
provider "aws" {
  alias   = "us_west"
  region  = var.regions.us_west
  profile = "hyundai-poc"

  default_tags {
    tags = var.tags
  }
}

# Get AWS Account ID
data "aws_caller_identity" "current" {}

# Get Secrets Manager secret for database password (US-East)
data "aws_secretsmanager_secret" "db_password_us_east" {
  provider = aws.us_east
  name     = "hyundai-poc/db-password"
}

# Get Secrets Manager secret for database password (Seoul)
data "aws_secretsmanager_secret" "db_password_seoul" {
  provider = aws.seoul
  name     = "hyundai-poc/db-password"
}

# Get Secrets Manager secret for database password (US-West)
data "aws_secretsmanager_secret" "db_password_us_west" {
  provider = aws.us_west
  name     = "hyundai-poc/db-password"
}

# ====================
# Seoul Infrastructure
# ====================

module "vpc_seoul" {
  source = "./modules/vpc"
  providers = {
    aws = aws.seoul
  }

  project_name = var.project_name
  region_name  = "seoul"
  vpc_cidr     = var.vpc_cidrs.seoul
  tags         = var.tags
}

module "security_groups_seoul" {
  source = "./modules/security-groups"
  providers = {
    aws = aws.seoul
  }

  project_name = var.project_name
  region_name  = "seoul"
  vpc_id       = module.vpc_seoul.vpc_id
  tags         = var.tags
}

module "iam_seoul" {
  source = "./modules/iam"
  providers = {
    aws = aws.seoul
  }

  project_name   = var.project_name
  region_name    = "seoul"
  aws_account_id = data.aws_caller_identity.current.account_id
  tags           = var.tags
}

module "alb_seoul" {
  source = "./modules/alb"
  providers = {
    aws = aws.seoul
  }

  project_name      = var.project_name
  region_name       = "seoul"
  vpc_id            = module.vpc_seoul.vpc_id
  public_subnet_ids = module.vpc_seoul.public_subnet_ids
  security_group_id = module.security_groups_seoul.alb_security_group_id
  certificate_arn   = module.acm_seoul.certificate_arn
  domain_name       = var.domain_name
  tags              = var.tags
}

# ====================
# US-East Infrastructure (Primary Region)
# ====================

module "vpc_us_east" {
  source = "./modules/vpc"
  providers = {
    aws = aws.us_east
  }

  project_name = var.project_name
  region_name  = "us-east"
  vpc_cidr     = var.vpc_cidrs.us_east
  tags         = var.tags
}

module "security_groups_us_east" {
  source = "./modules/security-groups"
  providers = {
    aws = aws.us_east
  }

  project_name = var.project_name
  region_name  = "us-east"
  vpc_id       = module.vpc_us_east.vpc_id
  tags         = var.tags
}

module "iam_us_east" {
  source = "./modules/iam"
  providers = {
    aws = aws.us_east
  }

  project_name   = var.project_name
  region_name    = "us-east"
  aws_account_id = data.aws_caller_identity.current.account_id
  tags           = var.tags
}

module "alb_us_east" {
  source = "./modules/alb"
  providers = {
    aws = aws.us_east
  }

  project_name      = var.project_name
  region_name       = "us-east"
  vpc_id            = module.vpc_us_east.vpc_id
  public_subnet_ids = module.vpc_us_east.public_subnet_ids
  security_group_id = module.security_groups_us_east.alb_security_group_id
  certificate_arn   = module.acm_us_east.certificate_arn
  domain_name       = var.domain_name
  tags              = var.tags
}

# ====================
# US-West Infrastructure
# ====================

module "vpc_us_west" {
  source = "./modules/vpc"
  providers = {
    aws = aws.us_west
  }

  project_name = var.project_name
  region_name  = "us-west"
  vpc_cidr     = var.vpc_cidrs.us_west
  tags         = var.tags
}

module "security_groups_us_west" {
  source = "./modules/security-groups"
  providers = {
    aws = aws.us_west
  }

  project_name = var.project_name
  region_name  = "us-west"
  vpc_id       = module.vpc_us_west.vpc_id
  tags         = var.tags
}

module "iam_us_west" {
  source = "./modules/iam"
  providers = {
    aws = aws.us_west
  }

  project_name   = var.project_name
  region_name    = "us-west"
  aws_account_id = data.aws_caller_identity.current.account_id
  tags           = var.tags
}

module "alb_us_west" {
  source = "./modules/alb"
  providers = {
    aws = aws.us_west
  }

  project_name      = var.project_name
  region_name       = "us-west"
  vpc_id            = module.vpc_us_west.vpc_id
  public_subnet_ids = module.vpc_us_west.public_subnet_ids
  security_group_id = module.security_groups_us_west.alb_security_group_id
  certificate_arn   = module.acm_us_west.certificate_arn
  domain_name       = var.domain_name
  tags              = var.tags
}

# ====================
# Aurora Global Database
# ====================

# Primary Aurora Cluster (US-East)
module "aurora_us_east" {
  source = "./modules/aurora"
  providers = {
    aws = aws.us_east
  }

  project_name       = var.project_name
  region_name        = "us-east"
  is_primary         = true
  
  # Primary는 이 값들을 설정
  db_name            = var.db_name
  master_username    = var.db_master_username
  master_password    = var.db_master_password
  
  # Primary에서는 global_cluster_id를 null로 설정
  global_cluster_id  = null
  
  private_subnet_ids = module.vpc_us_east.private_subnet_ids
  security_group_id  = module.security_groups_us_east.aurora_security_group_id
  min_capacity       = var.aurora_serverless_min_capacity
  max_capacity       = var.aurora_serverless_max_capacity
  tags               = var.tags
}

# Secondary Aurora Cluster (US-West)
module "aurora_us_west" {
  source = "./modules/aurora"
  providers = {
    aws = aws.us_west
  }

  project_name        = var.project_name
  region_name         = "us-west"
  is_primary          = false
  
  # Secondary는 이 값들을 null로 설정 (중요!)
  db_name             = null
  master_username     = null
  master_password     = null
  
  # Primary의 global cluster ID를 동적으로 참조
  global_cluster_id   = module.aurora_us_east.global_cluster_id
  
  private_subnet_ids  = module.vpc_us_west.private_subnet_ids
  security_group_id   = module.security_groups_us_west.aurora_security_group_id
  min_capacity        = var.aurora_serverless_min_capacity
  max_capacity        = var.aurora_serverless_max_capacity
  tags                = var.tags

  # Primary가 완전히 생성된 후에 생성
  depends_on = [module.aurora_us_east]
}

# Secondary Aurora Cluster (Seoul)
module "aurora_seoul" {
  source = "./modules/aurora"
  providers = {
    aws = aws.seoul
  }

  project_name        = var.project_name
  region_name         = "seoul"
  is_primary          = false
  
  # Secondary는 이 값들을 null로 설정 (중요!)
  db_name             = null
  master_username     = null
  master_password     = null
  
  # Primary의 global cluster ID를 동적으로 참조
  global_cluster_id   = module.aurora_us_east.global_cluster_id
  
  private_subnet_ids  = module.vpc_seoul.private_subnet_ids
  security_group_id   = module.security_groups_seoul.aurora_security_group_id
  min_capacity        = var.aurora_serverless_min_capacity
  max_capacity        = var.aurora_serverless_max_capacity
  tags                = var.tags

  # Primary가 완전히 생성된 후에 생성
  depends_on = [module.aurora_us_east, module.aurora_us_west]
}


# ====================
# ECS Services (placeholder image URIs - update after pushing to ECR)
# ====================

# Seoul ECS Services
module "ecs_seoul" {
  source = "./modules/ecs"
  providers = {
    aws = aws.seoul
  }

  project_name               = var.project_name
  region_name                = "seoul"
  aws_region                 = var.regions.seoul
  task_cpu                   = var.ecs_cpu
  task_memory                = var.ecs_memory
  desired_count              = 1
  enable_frontend            = false  # Frontend only in US-East
  frontend_image             = ""
  backend_image              = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.regions.seoul}.amazonaws.com/hyundai-poc-backend:latest"
  private_subnet_ids         = module.vpc_seoul.private_subnet_ids
  ecs_security_group_id      = module.security_groups_seoul.ecs_security_group_id
  execution_role_arn         = module.iam_seoul.ecs_execution_role_arn
  task_role_arn              = module.iam_seoul.ecs_task_role_arn
  frontend_target_group_arn  = module.alb_seoul.frontend_target_group_arn
  backend_target_group_arn   = module.alb_seoul.backend_target_group_arn
  alb_listener_arn           = module.alb_seoul.http_listener_arn
  db_writer_endpoint         = module.aurora_us_east.writer_endpoint
  db_reader_endpoint         = module.aurora_seoul.reader_endpoint
  db_name                    = var.db_name
  db_username                = var.db_master_username
  db_password_secret_arn     = data.aws_secretsmanager_secret.db_password_seoul.arn
  backend_url                = "https://api.${var.domain_name}"
  domain_name                = var.domain_name
  tags                       = var.tags

  depends_on = [
    module.aurora_us_east,
    module.aurora_seoul
  ]
}

# US-East ECS Services
module "ecs_us_east" {
  source = "./modules/ecs"
  providers = {
    aws = aws.us_east
  }

  project_name               = var.project_name
  region_name                = "us-east"
  aws_region                 = var.regions.us_east
  task_cpu                   = var.ecs_cpu
  task_memory                = var.ecs_memory
  desired_count              = 1
  frontend_image             = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.regions.us_east}.amazonaws.com/hyundai-poc-frontend:latest"
  backend_image              = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.regions.us_east}.amazonaws.com/hyundai-poc-backend:latest"
  private_subnet_ids         = module.vpc_us_east.private_subnet_ids
  ecs_security_group_id      = module.security_groups_us_east.ecs_security_group_id
  execution_role_arn         = module.iam_us_east.ecs_execution_role_arn
  task_role_arn              = module.iam_us_east.ecs_task_role_arn
  frontend_target_group_arn  = module.alb_us_east.frontend_target_group_arn
  backend_target_group_arn   = module.alb_us_east.backend_target_group_arn
  alb_listener_arn           = module.alb_us_east.http_listener_arn
  db_writer_endpoint         = module.aurora_us_east.writer_endpoint
  db_reader_endpoint         = module.aurora_us_east.reader_endpoint
  db_name                    = var.db_name
  db_username                = var.db_master_username
  db_password_secret_arn     = data.aws_secretsmanager_secret.db_password_us_east.arn
  backend_url                = "https://api.${var.domain_name}"
  domain_name                = var.domain_name
  tags                       = var.tags

  depends_on = [
    module.aurora_us_east
  ]
}

# US-West ECS Services
module "ecs_us_west" {
  source = "./modules/ecs"
  providers = {
    aws = aws.us_west
  }

  project_name               = var.project_name
  region_name                = "us-west"
  aws_region                 = var.regions.us_west
  task_cpu                   = var.ecs_cpu
  task_memory                = var.ecs_memory
  desired_count              = 1
  enable_frontend            = false  # Frontend only in US-East
  frontend_image             = ""
  backend_image              = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.regions.us_west}.amazonaws.com/hyundai-poc-backend:latest"
  private_subnet_ids         = module.vpc_us_west.private_subnet_ids
  ecs_security_group_id      = module.security_groups_us_west.ecs_security_group_id
  execution_role_arn         = module.iam_us_west.ecs_execution_role_arn
  task_role_arn              = module.iam_us_west.ecs_task_role_arn
  frontend_target_group_arn  = module.alb_us_west.frontend_target_group_arn
  backend_target_group_arn   = module.alb_us_west.backend_target_group_arn
  alb_listener_arn           = module.alb_us_west.http_listener_arn
  db_writer_endpoint         = module.aurora_us_east.writer_endpoint
  db_reader_endpoint         = module.aurora_us_west.reader_endpoint
  db_name                    = var.db_name
  db_username                = var.db_master_username
  db_password_secret_arn     = data.aws_secretsmanager_secret.db_password_us_west.arn
  backend_url                = "https://api.${var.domain_name}"
  domain_name                = var.domain_name
  tags                       = var.tags

  depends_on = [
    module.aurora_us_east,
    module.aurora_us_west
  ]
}

# ====================
# ACM SSL/TLS Certificates
# ====================

# ACM Certificate for CloudFront (must be in us-east-1)
module "acm_cloudfront" {
  source = "./modules/acm"
  providers = {
    aws = aws.us_east
  }

  project_name = var.project_name
  region_name  = "cloudfront"
  domain_name  = var.domain_name
  subject_alternative_names = [
    "*.${var.domain_name}"
  ]
  hosted_zone_id = "Z02639281DPI9IL5CWW86"
  tags           = var.tags
}

# ACM Certificate for Seoul ALB
module "acm_seoul" {
  source = "./modules/acm"
  providers = {
    aws = aws.seoul
  }

  project_name = var.project_name
  region_name  = "seoul"
  domain_name  = var.domain_name
  subject_alternative_names = [
    "*.${var.domain_name}"
  ]
  hosted_zone_id = "Z02639281DPI9IL5CWW86"
  tags           = var.tags
}

# ACM Certificate for US-East ALB
module "acm_us_east" {
  source = "./modules/acm"
  providers = {
    aws = aws.us_east
  }

  project_name = var.project_name
  region_name  = "us-east-alb"
  domain_name  = var.domain_name
  subject_alternative_names = [
    "*.${var.domain_name}"
  ]
  hosted_zone_id = "Z02639281DPI9IL5CWW86"
  tags           = var.tags
}

# ACM Certificate for US-West ALB
module "acm_us_west" {
  source = "./modules/acm"
  providers = {
    aws = aws.us_west
  }

  project_name = var.project_name
  region_name  = "us-west"
  domain_name  = var.domain_name
  subject_alternative_names = [
    "*.${var.domain_name}"
  ]
  hosted_zone_id = "Z02639281DPI9IL5CWW86"
  tags           = var.tags
}

# ====================
# Route53 DNS and Health Checks
# ====================

module "route53" {
  source = "./modules/route53"
  providers = {
    aws = aws.us_east
  }

  project_name = var.project_name
  domain_name  = var.domain_name

  # Use existing alwaysummer.dev hosted zone
  create_hosted_zone = false
  hosted_zone_id     = "Z02639281DPI9IL5CWW86"

  # ALB DNS names from each region
  seoul_alb_dns_name   = module.alb_seoul.alb_dns_name
  us_east_alb_dns_name = module.alb_us_east.alb_dns_name
  us_west_alb_dns_name = module.alb_us_west.alb_dns_name

  # ALB hosted zone IDs for alias records
  seoul_alb_zone_id   = module.alb_seoul.alb_zone_id
  us_east_alb_zone_id = module.alb_us_east.alb_zone_id
  us_west_alb_zone_id = module.alb_us_west.alb_zone_id

  # CloudFront distributions
  cloudfront_domain_name     = module.cloudfront.frontend_distribution_domain_name
  cloudfront_api_domain_name = module.cloudfront.api_distribution_domain_name

  tags = var.tags

  depends_on = [
    module.alb_seoul,
    module.alb_us_east,
    module.alb_us_west,
    module.cloudfront
  ]
}

# ====================
# CloudFront CDN Distribution
# ====================

module "cloudfront" {
  source = "./modules/cloudfront"
  providers = {
    aws = aws.us_east
  }

  project_name    = var.project_name
  domain_name     = var.domain_name
  certificate_arn = module.acm_cloudfront.certificate_arn

  # Origin ALB DNS names
  seoul_alb_dns_name   = "api-direct-seoul.hyundai.alwaysummer.dev"
  us_east_alb_dns_name = "api-direct-us-east.hyundai.alwaysummer.dev"
  us_west_alb_dns_name = "api-direct-us-west.hyundai.alwaysummer.dev"

  tags = var.tags

  depends_on = [
    module.alb_seoul,
    module.alb_us_east,
    module.alb_us_west,
    module.acm_cloudfront
  ]
}

# ====================
# CloudWatch Monitoring and Kinesis
# ====================

module "monitoring" {
  source = "./modules/monitoring"
  providers = {
    aws = aws.us_east
  }

  project_name = var.project_name

  # ECS cluster names
  seoul_ecs_cluster_name   = module.ecs_seoul.cluster_name
  us_east_ecs_cluster_name = module.ecs_us_east.cluster_name
  us_west_ecs_cluster_name = module.ecs_us_west.cluster_name

  # ECS service names
  seoul_frontend_service_name   = module.ecs_seoul.frontend_service_name
  seoul_backend_service_name    = module.ecs_seoul.backend_service_name
  us_east_frontend_service_name = module.ecs_us_east.frontend_service_name
  us_east_backend_service_name  = module.ecs_us_east.backend_service_name
  us_west_frontend_service_name = module.ecs_us_west.frontend_service_name
  us_west_backend_service_name  = module.ecs_us_west.backend_service_name

  # ALB ARN suffixes
  seoul_alb_arn_suffix   = module.alb_seoul.alb_arn_suffix
  us_east_alb_arn_suffix = module.alb_us_east.alb_arn_suffix
  us_west_alb_arn_suffix = module.alb_us_west.alb_arn_suffix

  # Target group ARN suffixes
  seoul_frontend_tg_arn_suffix   = module.alb_seoul.frontend_target_group_arn_suffix
  seoul_backend_tg_arn_suffix    = module.alb_seoul.backend_target_group_arn_suffix
  us_east_frontend_tg_arn_suffix = module.alb_us_east.frontend_target_group_arn_suffix
  us_east_backend_tg_arn_suffix  = module.alb_us_east.backend_target_group_arn_suffix
  us_west_frontend_tg_arn_suffix = module.alb_us_west.frontend_target_group_arn_suffix
  us_west_backend_tg_arn_suffix  = module.alb_us_west.backend_target_group_arn_suffix

  tags = var.tags

  depends_on = [
    module.ecs_seoul,
    module.ecs_us_east,
    module.ecs_us_west,
    module.aurora_seoul,
    module.aurora_us_east,
    module.aurora_us_west,
    module.alb_seoul,
    module.alb_us_east,
    module.alb_us_west
  ]
}
