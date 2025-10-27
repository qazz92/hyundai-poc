#!/bin/bash

# Hyundai Motors POC - ECR Repository Creation Script
# Creates frontend and backend ECR repositories in all 3 regions

set -e

echo "=========================================="
echo "Creating ECR Repositories"
echo "=========================================="

REGIONS=("ap-northeast-2" "us-east-1" "us-west-2")
REPOSITORIES=("hyundai-poc-frontend" "hyundai-poc-backend")

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

for region in "${REGIONS[@]}"; do
    echo -e "\n${YELLOW}Creating repositories in $region${NC}"

    for repo in "${REPOSITORIES[@]}"; do
        echo -n "  Creating $repo... "

        # Check if repository already exists
        if aws ecr describe-repositories \
            --repository-names $repo \
            --region $region \
            --profile hyundai-poc &> /dev/null; then
            echo -e "${GREEN}Already exists${NC}"
        else
            # Create repository
            aws ecr create-repository \
                --repository-name $repo \
                --region $region \
                --profile hyundai-poc \
                --image-scanning-configuration scanOnPush=true \
                --tags Key=Project,Value=Hyundai-POC Key=Environment,Value=Interview \
                > /dev/null
            echo -e "${GREEN}Created${NC}"
        fi
    done
done

echo ""
echo -e "${GREEN}✓ All ECR repositories created successfully!${NC}"
echo ""
echo "Summary:"
echo "- 6 repositories created (frontend + backend in 3 regions)"
echo "- Regions: ap-northeast-2, us-east-1, us-west-2"
echo ""
echo "Next step: Build and push Docker images to ECR"
