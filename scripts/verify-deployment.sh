#!/bin/bash

# Hyundai Motors POC - Deployment Verification Script
# Checks all infrastructure components are healthy and running

set -e

echo "=========================================="
echo "Hyundai Motors POC - Deployment Verification"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Symbols
CHECK="${GREEN}✓${NC}"
CROSS="${RED}✗${NC}"
WARN="${YELLOW}⚠${NC}"

# AWS Profile
AWS_PROFILE="${AWS_PROFILE:-hyundai-poc}"

# Regions
REGIONS=("ap-northeast-2" "us-east-1" "us-west-2")
REGION_NAMES=("Seoul" "US-East" "US-West")

# Counter for failures
FAILURES=0
WARNINGS=0

# Helper function to check command status
check_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${CHECK} $2"
    else
        echo -e "${CROSS} $2"
        ((FAILURES++))
    fi
}

# Helper function for warnings
warn_status() {
    echo -e "${WARN} $1"
    ((WARNINGS++))
}

echo -e "${BLUE}=== 1. ECS Services Health ===${NC}\n"

for i in "${!REGIONS[@]}"; do
    REGION="${REGIONS[$i]}"
    REGION_NAME="${REGION_NAMES[$i]}"

    echo -e "${YELLOW}Checking ECS services in $REGION_NAME ($REGION)...${NC}"

    # Get ECS cluster name
    CLUSTER_NAME="hyundai-poc-cluster-${REGION_NAME,,}"

    # Check if cluster exists
    CLUSTER_STATUS=$(aws ecs describe-clusters \
        --clusters "$CLUSTER_NAME" \
        --region "$REGION" \
        --profile "$AWS_PROFILE" \
        --query 'clusters[0].status' \
        --output text 2>/dev/null || echo "NOT_FOUND")

    if [ "$CLUSTER_STATUS" = "ACTIVE" ]; then
        check_status 0 "ECS Cluster: $CLUSTER_NAME"

        # List all services in the cluster
        SERVICES=$(aws ecs list-services \
            --cluster "$CLUSTER_NAME" \
            --region "$REGION" \
            --profile "$AWS_PROFILE" \
            --query 'serviceArns' \
            --output text 2>/dev/null)

        if [ -n "$SERVICES" ]; then
            # Describe services
            for SERVICE_ARN in $SERVICES; do
                SERVICE_NAME=$(echo "$SERVICE_ARN" | awk -F'/' '{print $NF}')

                SERVICE_INFO=$(aws ecs describe-services \
                    --cluster "$CLUSTER_NAME" \
                    --services "$SERVICE_ARN" \
                    --region "$REGION" \
                    --profile "$AWS_PROFILE" \
                    --query 'services[0].[runningCount,desiredCount,status]' \
                    --output text 2>/dev/null)

                RUNNING_COUNT=$(echo "$SERVICE_INFO" | awk '{print $1}')
                DESIRED_COUNT=$(echo "$SERVICE_INFO" | awk '{print $2}')
                SERVICE_STATUS=$(echo "$SERVICE_INFO" | awk '{print $3}')

                if [ "$RUNNING_COUNT" = "$DESIRED_COUNT" ] && [ "$SERVICE_STATUS" = "ACTIVE" ]; then
                    check_status 0 "  Service: $SERVICE_NAME ($RUNNING_COUNT/$DESIRED_COUNT tasks)"
                elif [ "$RUNNING_COUNT" -lt "$DESIRED_COUNT" ]; then
                    warn_status "  Service: $SERVICE_NAME ($RUNNING_COUNT/$DESIRED_COUNT tasks) - Starting up"
                else
                    check_status 1 "  Service: $SERVICE_NAME ($RUNNING_COUNT/$DESIRED_COUNT tasks)"
                fi
            done
        else
            warn_status "  No services found in cluster $CLUSTER_NAME"
        fi
    else
        check_status 1 "ECS Cluster: $CLUSTER_NAME (Status: $CLUSTER_STATUS)"
    fi

    echo ""
done

echo -e "${BLUE}=== 2. ALB Target Health ===${NC}\n"

for i in "${!REGIONS[@]}"; do
    REGION="${REGIONS[$i]}"
    REGION_NAME="${REGION_NAMES[$i]}"

    echo -e "${YELLOW}Checking ALB target groups in $REGION_NAME ($REGION)...${NC}"

    # Get all target groups with Project=Hyundai-POC tag
    TARGET_GROUPS=$(aws elbv2 describe-target-groups \
        --region "$REGION" \
        --profile "$AWS_PROFILE" \
        --query 'TargetGroups[*].TargetGroupArn' \
        --output text 2>/dev/null || echo "")

    if [ -n "$TARGET_GROUPS" ]; then
        for TG_ARN in $TARGET_GROUPS; do
            TG_NAME=$(aws elbv2 describe-target-groups \
                --target-group-arns "$TG_ARN" \
                --region "$REGION" \
                --profile "$AWS_PROFILE" \
                --query 'TargetGroups[0].TargetGroupName' \
                --output text 2>/dev/null)

            # Check if target group name contains hyundai-poc
            if [[ "$TG_NAME" == *"hyundai-poc"* ]]; then
                # Get target health
                HEALTH_INFO=$(aws elbv2 describe-target-health \
                    --target-group-arn "$TG_ARN" \
                    --region "$REGION" \
                    --profile "$AWS_PROFILE" \
                    --query 'TargetHealthDescriptions[*].TargetHealth.State' \
                    --output text 2>/dev/null || echo "")

                if [ -n "$HEALTH_INFO" ]; then
                    HEALTHY_COUNT=$(echo "$HEALTH_INFO" | tr ' ' '\n' | grep -c "healthy" || echo "0")
                    TOTAL_COUNT=$(echo "$HEALTH_INFO" | wc -w)

                    if [ "$HEALTHY_COUNT" -eq "$TOTAL_COUNT" ] && [ "$TOTAL_COUNT" -gt 0 ]; then
                        check_status 0 "  Target Group: $TG_NAME ($HEALTHY_COUNT/$TOTAL_COUNT healthy)"
                    elif [ "$HEALTHY_COUNT" -gt 0 ]; then
                        warn_status "  Target Group: $TG_NAME ($HEALTHY_COUNT/$TOTAL_COUNT healthy)"
                    else
                        check_status 1 "  Target Group: $TG_NAME ($HEALTHY_COUNT/$TOTAL_COUNT healthy)"
                    fi
                else
                    warn_status "  Target Group: $TG_NAME (No targets registered)"
                fi
            fi
        done
    else
        warn_status "  No target groups found"
    fi

    echo ""
done

echo -e "${BLUE}=== 3. Aurora Cluster Status ===${NC}\n"

for i in "${!REGIONS[@]}"; do
    REGION="${REGIONS[$i]}"
    REGION_NAME="${REGION_NAMES[$i]}"

    echo -e "${YELLOW}Checking Aurora clusters in $REGION_NAME ($REGION)...${NC}"

    # Get all DB clusters
    CLUSTERS=$(aws rds describe-db-clusters \
        --region "$REGION" \
        --profile "$AWS_PROFILE" \
        --query 'DBClusters[?contains(DBClusterIdentifier, `hyundai-poc`) || contains(DBClusterIdentifier, `marketing`)].[DBClusterIdentifier,Status,Engine]' \
        --output text 2>/dev/null || echo "")

    if [ -n "$CLUSTERS" ]; then
        echo "$CLUSTERS" | while read -r CLUSTER_ID STATUS ENGINE; do
            if [ "$STATUS" = "available" ]; then
                # Get cluster endpoints
                WRITER_ENDPOINT=$(aws rds describe-db-clusters \
                    --db-cluster-identifier "$CLUSTER_ID" \
                    --region "$REGION" \
                    --profile "$AWS_PROFILE" \
                    --query 'DBClusters[0].Endpoint' \
                    --output text 2>/dev/null)

                READER_ENDPOINT=$(aws rds describe-db-clusters \
                    --db-cluster-identifier "$CLUSTER_ID" \
                    --region "$REGION" \
                    --profile "$AWS_PROFILE" \
                    --query 'DBClusters[0].ReaderEndpoint' \
                    --output text 2>/dev/null)

                check_status 0 "  Cluster: $CLUSTER_ID ($ENGINE)"
                echo -e "    ${BLUE}Writer:${NC} $WRITER_ENDPOINT"
                echo -e "    ${BLUE}Reader:${NC} $READER_ENDPOINT"
            else
                check_status 1 "  Cluster: $CLUSTER_ID (Status: $STATUS)"
            fi
        done
    else
        warn_status "  No Aurora clusters found"
    fi

    echo ""
done

echo -e "${BLUE}=== 4. Route53 DNS Records ===${NC}\n"

# Get hosted zone ID for hyundai-poc.com
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones \
    --profile "$AWS_PROFILE" \
    --query 'HostedZones[?contains(Name, `hyundai-poc`)].Id' \
    --output text 2>/dev/null | awk -F'/' '{print $NF}')

if [ -n "$HOSTED_ZONE_ID" ]; then
    check_status 0 "Hosted Zone ID: $HOSTED_ZONE_ID"

    # Get record sets
    RECORD_SETS=$(aws route53 list-resource-record-sets \
        --hosted-zone-id "$HOSTED_ZONE_ID" \
        --profile "$AWS_PROFILE" \
        --query 'ResourceRecordSets[?Type==`A` || Type==`CNAME`].[Name,Type]' \
        --output text 2>/dev/null)

    if [ -n "$RECORD_SETS" ]; then
        echo "$RECORD_SETS" | while read -r NAME TYPE; do
            check_status 0 "  DNS Record: $NAME ($TYPE)"
        done
    else
        warn_status "  No A or CNAME records found"
    fi
else
    warn_status "No Route53 hosted zone found for hyundai-poc.com"
fi

echo ""

echo -e "${BLUE}=== 5. CloudFront Distribution ===${NC}\n"

# Get CloudFront distributions
DISTRIBUTIONS=$(aws cloudfront list-distributions \
    --profile "$AWS_PROFILE" \
    --query 'DistributionList.Items[?contains(Comment, `hyundai-poc`) || contains(Comment, `Hyundai`)].[Id,Status,DomainName]' \
    --output text 2>/dev/null || echo "")

if [ -n "$DISTRIBUTIONS" ]; then
    echo "$DISTRIBUTIONS" | while read -r DIST_ID STATUS DOMAIN; do
        if [ "$STATUS" = "Deployed" ]; then
            check_status 0 "Distribution: $DIST_ID ($STATUS)"
            echo -e "  ${BLUE}Domain:${NC} https://$DOMAIN"
        else
            warn_status "Distribution: $DIST_ID ($STATUS)"
        fi
    done
else
    warn_status "No CloudFront distributions found"
fi

echo ""

echo -e "${BLUE}=== 6. Health Check Tests ===${NC}\n"

# Get ALB DNS names and test health endpoints
for i in "${!REGIONS[@]}"; do
    REGION="${REGIONS[$i]}"
    REGION_NAME="${REGION_NAMES[$i]}"

    echo -e "${YELLOW}Testing health endpoints in $REGION_NAME...${NC}"

    # Get ALB DNS names
    ALB_DNS=$(aws elbv2 describe-load-balancers \
        --region "$REGION" \
        --profile "$AWS_PROFILE" \
        --query 'LoadBalancers[?contains(LoadBalancerName, `hyundai-poc`)].DNSName' \
        --output text 2>/dev/null | head -1)

    if [ -n "$ALB_DNS" ]; then
        # Test health endpoint
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS/health" --max-time 10 2>/dev/null || echo "000")

        if [ "$HTTP_CODE" = "200" ]; then
            check_status 0 "  Health endpoint: http://$ALB_DNS/health (HTTP $HTTP_CODE)"
        elif [ "$HTTP_CODE" = "000" ]; then
            warn_status "  Health endpoint: http://$ALB_DNS/health (Connection timeout)"
        else
            check_status 1 "  Health endpoint: http://$ALB_DNS/health (HTTP $HTTP_CODE)"
        fi
    else
        warn_status "  No ALB found in $REGION_NAME"
    fi
done

echo ""

echo "=========================================="
echo -e "${BLUE}=== Verification Summary ===${NC}"
echo "=========================================="
echo ""

if [ $FAILURES -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo ""
    echo "Your Hyundai Motors POC infrastructure is fully deployed and healthy."
    echo ""
    echo "Next steps:"
    echo "  1. Run ./scripts/test-latency.sh to measure cross-region latency"
    echo "  2. Run ./scripts/test-replication.sh to test Aurora replication"
    echo "  3. Run ./scripts/test-dns.sh to verify geographic routing"
    echo "  4. Access the CloudWatch dashboard to view metrics"
    echo ""
    exit 0
elif [ $FAILURES -eq 0 ]; then
    echo -e "${YELLOW}⚠ Checks completed with $WARNINGS warning(s)${NC}"
    echo ""
    echo "Some components may still be starting up. Wait 2-3 minutes and re-run this script."
    echo ""
    exit 0
else
    echo -e "${RED}✗ Verification failed with $FAILURES error(s) and $WARNINGS warning(s)${NC}"
    echo ""
    echo "Please review the errors above and check:"
    echo "  1. Terraform apply completed successfully"
    echo "  2. AWS CLI profile '$AWS_PROFILE' has correct permissions"
    echo "  3. All ECS services have finished deploying (may take 5-10 minutes)"
    echo "  4. Aurora clusters have finished creating (may take 15-20 minutes)"
    echo ""
    exit 1
fi
