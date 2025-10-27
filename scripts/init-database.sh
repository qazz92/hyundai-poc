#!/bin/bash

# Hyundai Motors POC - Database Initialization Script
# Connects to Aurora primary and runs initialization SQL

set -e

echo "=========================================="
echo "Database Initialization"
echo "=========================================="

# Check if mysql client is installed
if ! command -v mysql &> /dev/null; then
    echo "Error: mysql client not found. Please install MySQL client."
    echo "  macOS: brew install mysql-client"
    echo "  Ubuntu: sudo apt-get install mysql-client"
    exit 1
fi

# Get database password from Secrets Manager
echo "Retrieving database password from AWS Secrets Manager..."
DB_PASSWORD=$(aws secretsmanager get-secret-value \
    --secret-id hyundai-poc/db-password \
    --region us-east-1 \
    --profile hyundai-poc \
    --query SecretString \
    --output text)

# Get Aurora writer endpoint from Terraform outputs
echo "Getting Aurora writer endpoint..."
cd /Users/rokhun/hyundai/hyundai-motors-poc/terraform
WRITER_ENDPOINT=$(terraform output -json aurora_endpoints | jq -r '.primary.writer')

if [ -z "$WRITER_ENDPOINT" ] || [ "$WRITER_ENDPOINT" == "null" ]; then
    echo "Error: Could not retrieve Aurora writer endpoint from Terraform outputs"
    echo "Please ensure infrastructure is deployed: terraform apply"
    exit 1
fi

echo "Connecting to Aurora primary: $WRITER_ENDPOINT"
echo ""

# Run initialization SQL
mysql -h "$WRITER_ENDPOINT" \
    -u admin \
    -p"$DB_PASSWORD" \
    hyundai_poc \
    < ../terraform/modules/aurora/init.sql

echo ""
echo "✓ Database initialized successfully!"
echo ""
echo "Verifying replication to secondary regions..."

# Wait for replication
sleep 5

# Get Seoul reader endpoint
SEOUL_READER=$(terraform output -json aurora_endpoints | jq -r '.seoul.reader')

echo "Checking Seoul replica: $SEOUL_READER"
SEOUL_COUNT=$(mysql -h "$SEOUL_READER" \
    -u admin \
    -p"$DB_PASSWORD" \
    hyundai_poc \
    -N -e "SELECT COUNT(*) FROM health_checks;")

echo "  Records in Seoul: $SEOUL_COUNT"

# Get US-West reader endpoint
US_WEST_READER=$(terraform output -json aurora_endpoints | jq -r '.us_west.reader')

echo "Checking US-West replica: $US_WEST_READER"
US_WEST_COUNT=$(mysql -h "$US_WEST_READER" \
    -u admin \
    -p"$DB_PASSWORD" \
    hyundai_poc \
    -N -e "SELECT COUNT(*) FROM health_checks;")

echo "  Records in US-West: $US_WEST_COUNT"

echo ""
if [ "$SEOUL_COUNT" == "3" ] && [ "$US_WEST_COUNT" == "3" ]; then
    echo "✓ Replication verified! All regions have 3 records."
else
    echo "⚠ Replication incomplete. Wait a few seconds and check again."
fi
