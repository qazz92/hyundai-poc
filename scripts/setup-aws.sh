#!/bin/bash

# Hyundai Motors POC - AWS Setup Script
# This script configures AWS CLI and creates required resources

set -e

echo "=========================================="
echo "Hyundai Motors POC - AWS Setup"
echo "=========================================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configure AWS CLI profile
echo -e "\n${YELLOW}Step 1: Configure AWS CLI profile${NC}"
echo "Please enter your AWS credentials:"
aws configure --profile hyundai-poc

# Verify access to all 3 regions
echo -e "\n${YELLOW}Step 2: Verify access to all 3 regions${NC}"

REGIONS=("ap-northeast-2" "us-east-1" "us-west-2")
for region in "${REGIONS[@]}"; do
    echo -n "Testing access to $region... "
    if aws ec2 describe-regions --region-names $region --profile hyundai-poc &> /dev/null; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAILED${NC}"
        echo "Error: Cannot access region $region. Please check your credentials."
        exit 1
    fi
done

# Generate strong database password
echo -e "\n${YELLOW}Step 3: Generate database password${NC}"
DB_PASSWORD=$(openssl rand -base64 32)
echo "Generated database password (save this securely):"
echo "$DB_PASSWORD"

# Store password in AWS Secrets Manager
echo -e "\n${YELLOW}Step 4: Store password in AWS Secrets Manager${NC}"
echo "Creating secret in us-east-1..."
aws secretsmanager create-secret \
    --name hyundai-poc/db-password \
    --secret-string "$DB_PASSWORD" \
    --region us-east-1 \
    --profile hyundai-poc \
    --tags Key=Project,Value=Hyundai-POC Key=Environment,Value=Interview

echo "Replicating secret to other regions..."
aws secretsmanager replicate-secret-to-regions \
    --secret-id hyundai-poc/db-password \
    --add-replica-regions Region=ap-northeast-2 Region=us-west-2 \
    --region us-east-1 \
    --profile hyundai-poc

echo -e "${GREEN}✓ AWS setup complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Run ./scripts/create-ecr-repos.sh to create ECR repositories"
echo "2. Copy terraform/terraform.tfvars.example to terraform/terraform.tfvars"
echo "3. Update terraform.tfvars with your AWS account ID and generated password"
