#!/bin/bash
set -e

echo "==================================="
echo "Frontend Deployment Script"
echo "==================================="

# Configuration
AWS_ACCOUNT_ID="216066129448"
AWS_PROFILE="hyundai-poc"
IMAGE_NAME="hyundai-poc-frontend"
IMAGE_TAG="latest-$(date +%Y%m%d-%H%M%S)"

# Regions
REGIONS=("ap-northeast-2" "us-east-1" "us-west-2")
REGION_NAMES=("seoul" "us-east" "us-west")

# Navigate to frontend directory
cd "$(dirname "$0")/../application/frontend"

echo ""
echo "Step 1: Building Docker image for ARM64..."
docker build --no-cache --pull --platform linux/arm64 -t ${IMAGE_NAME}:${IMAGE_TAG} -t ${IMAGE_NAME}:latest .

echo ""
echo "Step 2: Deploying to all regions..."

for i in "${!REGIONS[@]}"; do
    REGION="${REGIONS[$i]}"
    REGION_NAME="${REGION_NAMES[$i]}"
    ECR_REPO="${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${IMAGE_NAME}"

    echo ""
    echo "-----------------------------------"
    echo "Deploying to ${REGION_NAME} (${REGION})"
    echo "-----------------------------------"

    # ECR Login
    echo "Logging into ECR..."
    aws ecr get-login-password --region ${REGION} --profile ${AWS_PROFILE} | \
        docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

    # Tag image for this region
    docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ECR_REPO}:${IMAGE_TAG}
    docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ECR_REPO}:latest

    # Push to ECR
    echo "Pushing image to ECR..."
    docker push ${ECR_REPO}:${IMAGE_TAG}
    docker push ${ECR_REPO}:latest

    # Update ECS service
    echo "Updating ECS service..."
    SERVICE_NAME="hyundai-poc-frontend-service-${REGION_NAME}"
    CLUSTER_NAME="hyundai-poc-cluster-${REGION_NAME}"

    aws ecs update-service \
        --cluster ${CLUSTER_NAME} \
        --service ${SERVICE_NAME} \
        --force-new-deployment \
        --region ${REGION} \
        --profile ${AWS_PROFILE} > /dev/null

    echo "✓ ECS service update triggered for ${REGION_NAME}"
done

echo ""
echo "==================================="
echo "✓ Deployment completed successfully!"
echo "Image tag: ${IMAGE_TAG}"
echo ""
echo "ECS services are now deploying the new image."
echo "This may take 2-3 minutes to complete."
echo "==================================="
