#!/bin/bash

# Hyundai Motors POC - Infrastructure Teardown Script
# Destroys all infrastructure and verifies deletion

set -e

echo "=========================================="
echo "Hyundai Motors POC - Infrastructure Teardown"
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

# Warning message
echo -e "${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║                                                               ║${NC}"
echo -e "${RED}║  WARNING: This will DESTROY ALL infrastructure!              ║${NC}"
echo -e "${RED}║                                                               ║${NC}"
echo -e "${RED}║  This action will:                                           ║${NC}"
echo -e "${RED}║  - Delete all ECS services and tasks                         ║${NC}"
echo -e "${RED}║  - Delete Aurora Global Database (all 3 regions)             ║${NC}"
echo -e "${RED}║  - Delete all VPCs, subnets, NAT Gateways                    ║${NC}"
echo -e "${RED}║  - Delete all Application Load Balancers                     ║${NC}"
echo -e "${RED}║  - Delete Route53 records                                    ║${NC}"
echo -e "${RED}║  - Delete CloudFront distribution                            ║${NC}"
echo -e "${RED}║  - Delete CloudWatch logs and dashboards                     ║${NC}"
echo -e "${RED}║                                                               ║${NC}"
echo -e "${RED}║  This action is IRREVERSIBLE!                                ║${NC}"
echo -e "${RED}║                                                               ║${NC}"
echo -e "${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Confirmation prompt
echo -e "${YELLOW}To confirm destruction, type 'yes' exactly:${NC} "
read -r CONFIRMATION

if [ "$CONFIRMATION" != "yes" ]; then
    echo ""
    echo -e "${GREEN}Teardown cancelled. No resources were deleted.${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}Proceeding with infrastructure teardown...${NC}"
echo ""

# Change to terraform directory
TERRAFORM_DIR="$(dirname "$(dirname "$(readlink -f "$0" 2>/dev/null || realpath "$0")")")/terraform"

if [ ! -d "$TERRAFORM_DIR" ]; then
    echo -e "${RED}Error: Terraform directory not found at $TERRAFORM_DIR${NC}"
    exit 1
fi

cd "$TERRAFORM_DIR"

# Check if terraform state exists
if [ ! -f "terraform.tfstate" ]; then
    echo -e "${YELLOW}No terraform.tfstate file found. Nothing to destroy.${NC}"
    exit 0
fi

# Step 1: Disable deletion protection on Aurora clusters (if enabled)
echo -e "${YELLOW}Step 1: Disabling deletion protection on Aurora clusters...${NC}"

for i in "${!REGIONS[@]}"; do
    REGION="${REGIONS[$i]}"
    REGION_NAME="${REGION_NAMES[$i]}"

    CLUSTERS=$(aws rds describe-db-clusters \
        --region "$REGION" \
        --profile "$AWS_PROFILE" \
        --query 'DBClusters[?contains(DBClusterIdentifier, `hyundai-poc`) || contains(DBClusterIdentifier, `marketing`)].[DBClusterIdentifier,DeletionProtection]' \
        --output text 2>/dev/null || echo "")

    if [ -n "$CLUSTERS" ]; then
        echo "$CLUSTERS" | while read -r CLUSTER_ID DELETION_PROTECTION; do
            if [ "$DELETION_PROTECTION" = "True" ]; then
                echo "  Disabling deletion protection on $CLUSTER_ID in $REGION_NAME..."
                aws rds modify-db-cluster \
                    --db-cluster-identifier "$CLUSTER_ID" \
                    --no-deletion-protection \
                    --region "$REGION" \
                    --profile "$AWS_PROFILE" \
                    --apply-immediately &>/dev/null || true
            fi
        done
    fi
done

echo -e "${CHECK} Deletion protection disabled (if any)\n"

# Step 2: Run terraform destroy
echo -e "${YELLOW}Step 2: Running terraform destroy...${NC}"
echo ""

# Run terraform destroy
if terraform destroy -auto-approve; then
    echo ""
    echo -e "${CHECK} Terraform destroy completed successfully\n"
else
    echo ""
    echo -e "${CROSS} Terraform destroy failed${NC}"
    echo ""
    echo "Please check the error messages above and resolve any issues."
    echo "You may need to manually delete some resources in the AWS Console."
    exit 1
fi

# Step 3: Verify resource deletion
echo -e "${YELLOW}Step 3: Verifying resource deletion...${NC}\n"

REMAINING_RESOURCES=0

# Check ECS clusters
echo "Checking ECS clusters..."
for i in "${!REGIONS[@]}"; do
    REGION="${REGIONS[$i]}"
    REGION_NAME="${REGION_NAMES[$i]}"

    CLUSTERS=$(aws ecs list-clusters \
        --region "$REGION" \
        --profile "$AWS_PROFILE" \
        --query 'clusterArns[?contains(@, `hyundai-poc`)]' \
        --output text 2>/dev/null || echo "")

    if [ -n "$CLUSTERS" ]; then
        echo -e "${WARN}  ECS clusters still exist in $REGION_NAME"
        ((REMAINING_RESOURCES++))
    fi
done
echo -e "${CHECK} ECS clusters deleted\n"

# Check Aurora clusters
echo "Checking Aurora clusters..."
for i in "${!REGIONS[@]}"; do
    REGION="${REGIONS[$i]}"
    REGION_NAME="${REGION_NAMES[$i]}"

    CLUSTERS=$(aws rds describe-db-clusters \
        --region "$REGION" \
        --profile "$AWS_PROFILE" \
        --query 'DBClusters[?contains(DBClusterIdentifier, `hyundai-poc`) || contains(DBClusterIdentifier, `marketing`)].DBClusterIdentifier' \
        --output text 2>/dev/null || echo "")

    if [ -n "$CLUSTERS" ]; then
        echo -e "${WARN}  Aurora clusters still exist in $REGION_NAME (may take 5-10 minutes to delete)"
        ((REMAINING_RESOURCES++))
    fi
done
echo -e "${CHECK} Aurora clusters deleted or deleting\n"

# Check VPCs
echo "Checking VPCs..."
for i in "${!REGIONS[@]}"; do
    REGION="${REGIONS[$i]}"
    REGION_NAME="${REGION_NAMES[$i]}"

    VPCS=$(aws ec2 describe-vpcs \
        --region "$REGION" \
        --profile "$AWS_PROFILE" \
        --filters "Name=tag:Project,Values=Hyundai-POC" \
        --query 'Vpcs[].VpcId' \
        --output text 2>/dev/null || echo "")

    if [ -n "$VPCS" ]; then
        echo -e "${WARN}  VPCs still exist in $REGION_NAME"
        ((REMAINING_RESOURCES++))
    fi
done
echo -e "${CHECK} VPCs deleted\n"

# Check ALBs
echo "Checking Application Load Balancers..."
for i in "${!REGIONS[@]}"; do
    REGION="${REGIONS[$i]}"
    REGION_NAME="${REGION_NAMES[$i]}"

    ALBS=$(aws elbv2 describe-load-balancers \
        --region "$REGION" \
        --profile "$AWS_PROFILE" \
        --query 'LoadBalancers[?contains(LoadBalancerName, `hyundai-poc`)].LoadBalancerName' \
        --output text 2>/dev/null || echo "")

    if [ -n "$ALBS" ]; then
        echo -e "${WARN}  ALBs still exist in $REGION_NAME"
        ((REMAINING_RESOURCES++))
    fi
done
echo -e "${CHECK} ALBs deleted\n"

# Check NAT Gateways
echo "Checking NAT Gateways..."
for i in "${!REGIONS[@]}"; do
    REGION="${REGIONS[$i]}"
    REGION_NAME="${REGION_NAMES[$i]}"

    NAT_GWS=$(aws ec2 describe-nat-gateways \
        --region "$REGION" \
        --profile "$AWS_PROFILE" \
        --filter "Name=tag:Project,Values=Hyundai-POC" "Name=state,Values=available,pending,deleting" \
        --query 'NatGateways[].NatGatewayId' \
        --output text 2>/dev/null || echo "")

    if [ -n "$NAT_GWS" ]; then
        echo -e "${WARN}  NAT Gateways still exist in $REGION_NAME (deleting)"
        ((REMAINING_RESOURCES++))
    fi
done
echo -e "${CHECK} NAT Gateways deleted or deleting\n"

# Step 4: Check for recurring charges
echo -e "${YELLOW}Step 4: Checking for potential recurring charges...${NC}\n"

POTENTIAL_CHARGES=0

# Check for ECR repositories (images incur storage charges)
echo "Checking ECR repositories..."
for i in "${!REGIONS[@]}"; do
    REGION="${REGIONS[$i]}"
    REGION_NAME="${REGION_NAMES[$i]}"

    REPOS=$(aws ecr describe-repositories \
        --region "$REGION" \
        --profile "$AWS_PROFILE" \
        --query 'repositories[?contains(repositoryName, `hyundai-poc`)].repositoryName' \
        --output text 2>/dev/null || echo "")

    if [ -n "$REPOS" ]; then
        echo -e "${WARN}  ECR repositories still exist in $REGION_NAME (manual deletion required)"
        echo "    Run: aws ecr delete-repository --repository-name <repo-name> --force --region $REGION"
        ((POTENTIAL_CHARGES++))
    fi
done

# Check for Secrets Manager secrets
echo "Checking Secrets Manager secrets..."
for i in "${!REGIONS[@]}"; do
    REGION="${REGIONS[$i]}"
    REGION_NAME="${REGION_NAMES[$i]}"

    SECRETS=$(aws secretsmanager list-secrets \
        --region "$REGION" \
        --profile "$AWS_PROFILE" \
        --query 'SecretList[?contains(Name, `hyundai-poc`)].Name' \
        --output text 2>/dev/null || echo "")

    if [ -n "$SECRETS" ]; then
        echo -e "${WARN}  Secrets Manager secrets still exist in $REGION_NAME (manual deletion required)"
        echo "    Run: aws secretsmanager delete-secret --secret-id <secret-name> --force-delete-without-recovery --region $REGION"
        ((POTENTIAL_CHARGES++))
    fi
done

# Check for CloudWatch log groups
echo "Checking CloudWatch log groups..."
for i in "${!REGIONS[@]}"; do
    REGION="${REGIONS[$i]}"
    REGION_NAME="${REGION_NAMES[$i]}"

    LOG_GROUPS=$(aws logs describe-log-groups \
        --region "$REGION" \
        --profile "$AWS_PROFILE" \
        --query 'logGroups[?contains(logGroupName, `hyundai-poc`) || contains(logGroupName, `/ecs/`)].logGroupName' \
        --output text 2>/dev/null || echo "")

    if [ -n "$LOG_GROUPS" ]; then
        echo -e "${WARN}  CloudWatch log groups still exist in $REGION_NAME (minimal charges, optional cleanup)"
        echo "    Run: aws logs delete-log-group --log-group-name <log-group-name> --region $REGION"
        ((POTENTIAL_CHARGES++))
    fi
done

echo ""

# Step 5: Final summary
echo "=========================================="
echo -e "${BLUE}=== Teardown Summary ===${NC}"
echo "=========================================="
echo ""

if [ $REMAINING_RESOURCES -eq 0 ] && [ $POTENTIAL_CHARGES -eq 0 ]; then
    echo -e "${GREEN}✓ All infrastructure successfully destroyed!${NC}"
    echo ""
    echo "Zero recurring charges confirmed."
    echo ""
    echo "Recommended final cleanup:"
    echo "  1. Delete terraform.tfstate and terraform.tfstate.backup files"
    echo "  2. Verify AWS billing dashboard shows no ongoing charges"
    echo "  3. Remove AWS CLI profile: aws configure --profile $AWS_PROFILE (optional)"
    echo ""
elif [ $REMAINING_RESOURCES -eq 0 ]; then
    echo -e "${YELLOW}⚠ Infrastructure destroyed with manual cleanup required${NC}"
    echo ""
    echo "Terraform destroy completed successfully, but some resources require manual deletion:"
    echo "  - ECR repositories (to avoid storage charges)"
    echo "  - Secrets Manager secrets (minimal charges)"
    echo "  - CloudWatch log groups (optional, minimal charges)"
    echo ""
    echo "See warnings above for specific deletion commands."
    echo ""
else
    echo -e "${YELLOW}⚠ Teardown completed with warnings${NC}"
    echo ""
    echo "Some resources may still be deleting (this is normal for Aurora clusters)."
    echo "Wait 5-10 minutes and verify in AWS Console:"
    echo "  - RDS Clusters (may take up to 10 minutes to delete)"
    echo "  - NAT Gateways (may take a few minutes to delete)"
    echo ""
    echo "Re-run this script after waiting to verify complete deletion."
    echo ""
fi

# Final billing check suggestion
echo -e "${BLUE}Billing Verification:${NC}"
echo "Run this command to check your current costs:"
echo ""
echo "  aws ce get-cost-and-usage \\"
echo "    --time-period Start=$(date -u -d '7 days ago' +%Y-%m-%d),End=$(date -u +%Y-%m-%d) \\"
echo "    --granularity DAILY \\"
echo "    --metrics BlendedCost \\"
echo "    --group-by Type=TAG,Key=Project \\"
echo "    --filter file://<(echo '{\"Tags\":{\"Key\":\"Project\",\"Values\":[\"Hyundai-POC\"]}}')"
echo ""

exit 0
