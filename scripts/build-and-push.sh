#!/bin/bash

# Hyundai Motors POC - Docker Build and Push Script
# This script builds frontend and backend containers and pushes them to all 3 regional ECR repositories

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================"
echo "Hyundai Motors POC - Docker Build & Push"
echo "========================================"
echo ""

# Configuration
PROFILE="hyundai-poc"
REGIONS=("ap-northeast-2" "us-east-1" "us-west-2")
REGION_NAMES=("Seoul" "US-East" "US-West")
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Check if AWS CLI is configured
if ! aws sts get-caller-identity --profile $PROFILE &> /dev/null; then
    echo -e "${RED}✗ AWS CLI not configured with profile '$PROFILE'${NC}"
    echo "Run ./scripts/setup-aws.sh first"
    exit 1
fi

# Get AWS Account ID
echo -e "${YELLOW}→ Getting AWS Account ID...${NC}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile $PROFILE)
echo -e "${GREEN}✓ AWS Account ID: $AWS_ACCOUNT_ID${NC}"
echo ""

# Build frontend container
echo "========================================"
echo "Building Frontend Container"
echo "========================================"
cd "$PROJECT_ROOT/application/frontend"

if [ ! -f "Dockerfile" ]; then
    echo -e "${RED}✗ Frontend Dockerfile not found${NC}"
    exit 1
fi

# Create .env file from .env.example if it doesn't exist
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}→ Creating .env from .env.example...${NC}"
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo -e "${GREEN}✓ .env file created (will use runtime ECS environment variables)${NC}"
    else
        echo -e "${YELLOW}⚠ No .env.example found, creating minimal .env${NC}"
        cat > .env << EOF
NEXT_PUBLIC_API_URL=http://localhost:3001
NEXT_PUBLIC_ALB_SEOUL_URL=http://seoul-alb.example.com/health
NEXT_PUBLIC_ALB_US_EAST_URL=http://us-east-alb.example.com/health
NEXT_PUBLIC_ALB_US_WEST_URL=http://us-west-alb.example.com/health
EOF
    fi
fi

# Generate package-lock.json if it doesn't exist
if [ ! -f "package-lock.json" ]; then
    echo -e "${YELLOW}→ Generating package-lock.json (running npm install)...${NC}"
    npm install > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ package-lock.json generated${NC}"
    else
        echo -e "${RED}✗ Failed to generate package-lock.json${NC}"
        exit 1
    fi
fi

echo -e "${YELLOW}→ Building frontend image (ARM64 for Graviton2)...${NC}"
docker build --platform linux/arm64 -t hyundai-poc-frontend:latest . --no-cache
echo -e "${GREEN}✓ Frontend image built (ARM64)${NC}"
echo ""

# Build backend container
echo "========================================"
echo "Building Backend Container"
echo "========================================"
cd "$PROJECT_ROOT/application/backend"

if [ ! -f "Dockerfile" ]; then
    echo -e "${RED}✗ Backend Dockerfile not found${NC}"
    exit 1
fi

# Create .env file from .env.example if it doesn't exist
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}→ Creating .env from .env.example...${NC}"
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo -e "${GREEN}✓ .env file created (will use runtime ECS environment variables)${NC}"
    else
        echo -e "${YELLOW}⚠ No .env.example found, creating minimal .env${NC}"
        cat > .env << EOF
AWS_REGION=us-east-1
DB_WRITER_HOST=localhost
DB_READER_HOST=localhost
DB_PORT=3306
DB_NAME=hyundai_poc
DB_USER=admin
DB_PASSWORD=placeholder
PORT=3001
LOG_LEVEL=info
ALB_SEOUL_URL=http://seoul-alb.example.com
ALB_US_EAST_URL=http://us-east-alb.example.com
ALB_US_WEST_URL=http://us-west-alb.example.com
EOF
    fi
fi

# Generate package-lock.json if it doesn't exist
if [ ! -f "package-lock.json" ]; then
    echo -e "${YELLOW}→ Generating package-lock.json (running npm install)...${NC}"
    npm install > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ package-lock.json generated${NC}"
    else
        echo -e "${RED}✗ Failed to generate package-lock.json${NC}"
        exit 1
    fi
fi

echo -e "${YELLOW}→ Building backend image (ARM64 for Graviton2)...${NC}"
docker build --platform linux/arm64 -t hyundai-poc-backend:latest . --no-cache
echo -e "${GREEN}✓ Backend image built (ARM64)${NC}"
echo ""

# Push to all regional ECRs
echo "========================================"
echo "Pushing to Regional ECRs"
echo "========================================"

for i in "${!REGIONS[@]}"; do
    REGION="${REGIONS[$i]}"
    REGION_NAME="${REGION_NAMES[$i]}"

    echo ""
    echo "--- Region: $REGION_NAME ($REGION) ---"

    # ECR Login
    echo -e "${YELLOW}→ Logging into ECR...${NC}"
    aws ecr get-login-password --region $REGION --profile $PROFILE | \
        docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Failed to login to ECR in $REGION${NC}"
        exit 1
    fi

    # Tag and push frontend
    echo -e "${YELLOW}→ Tagging and pushing frontend...${NC}"
    docker tag hyundai-poc-frontend:latest ${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/hyundai-poc-frontend:latest
    docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/hyundai-poc-frontend:latest

    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Failed to push frontend to $REGION${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Frontend pushed to $REGION_NAME${NC}"

    # Tag and push backend
    echo -e "${YELLOW}→ Tagging and pushing backend...${NC}"
    docker tag hyundai-poc-backend:latest ${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/hyundai-poc-backend:latest
    docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/hyundai-poc-backend:latest

    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Failed to push backend to $REGION${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Backend pushed to $REGION_NAME${NC}"
done

echo ""
echo "========================================"
echo -e "${GREEN}✓ All images built and pushed successfully!${NC}"
echo "========================================"
echo ""
echo "Images pushed to:"
for i in "${!REGIONS[@]}"; do
    REGION="${REGIONS[$i]}"
    REGION_NAME="${REGION_NAMES[$i]}"
    echo "  • $REGION_NAME ($REGION):"
    echo "    - ${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/hyundai-poc-frontend:latest"
    echo "    - ${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/hyundai-poc-backend:latest"
done
echo ""
echo "Next steps:"
echo "  1. cd terraform"
echo "  2. terraform init"
echo "  3. terraform plan -out=tfplan"
echo "  4. terraform apply tfplan"
echo ""
