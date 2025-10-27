#!/bin/bash

##############################################################################
# DNS Routing Validation Script
#
# Purpose: Verify Route53 geographic routing configuration
# Author: Hyundai Motors POC Team
# Usage: ./scripts/test-dns.sh
#
# This script:
# - Queries DNS for regional and global endpoints
# - Verifies geolocation routing policies
# - Tests DNS resolution from current location
# - Documents resolved IPs per geographic location
##############################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "================================================"
echo "Hyundai Motors POC - DNS Routing Validation"
echo "================================================"
echo ""

# DNS configuration
GLOBAL_DOMAIN="${GLOBAL_DOMAIN:-www.hyundai-poc.com}"
SEOUL_DOMAIN="${SEOUL_DOMAIN:-seoul.hyundai-poc.com}"
US_EAST_DOMAIN="${US_EAST_DOMAIN:-us-east.hyundai-poc.com}"
US_WEST_DOMAIN="${US_WEST_DOMAIN:-us-west.hyundai-poc.com}"

# Expected ALB endpoints (from terraform outputs)
SEOUL_ALB="${SEOUL_ALB:-}"
US_EAST_ALB="${US_EAST_ALB:-}"
US_WEST_ALB="${US_WEST_ALB:-}"

# Load from terraform outputs if not set
if [ -z "$SEOUL_ALB" ] || [ -z "$US_EAST_ALB" ] || [ -z "$US_WEST_ALB" ]; then
  if [ -f "terraform/outputs.json" ]; then
    echo "Loading ALB endpoints from terraform outputs..."
    SEOUL_ALB=$(cat terraform/outputs.json | grep -o '"seoul_alb_dns"[^,]*' | cut -d'"' -f4 || echo "")
    US_EAST_ALB=$(cat terraform/outputs.json | grep -o '"us_east_alb_dns"[^,]*' | cut -d'"' -f4 || echo "")
    US_WEST_ALB=$(cat terraform/outputs.json | grep -o '"us_west_alb_dns"[^,]*' | cut -d'"' -f4 || echo "")
  fi
fi

# Output file
OUTPUT_DIR="test-results"
mkdir -p "$OUTPUT_DIR"
OUTPUT_FILE="$OUTPUT_DIR/dns-validation.txt"

# Initialize output file
echo "DNS Routing Validation Results" > "$OUTPUT_FILE"
echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$OUTPUT_FILE"
echo "========================================" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

##############################################################################
# Function: resolve_dns
# Resolves DNS name and returns IP addresses
##############################################################################
resolve_dns() {
  local domain=$1
  local resolver=${2:-""}

  if [ -n "$resolver" ]; then
    dig +short "$domain" @"$resolver" 2>/dev/null || echo "RESOLUTION_FAILED"
  else
    dig +short "$domain" 2>/dev/null || echo "RESOLUTION_FAILED"
  fi
}

##############################################################################
# Function: test_dns_record
# Tests DNS resolution for a specific domain
##############################################################################
test_dns_record() {
  local record_name=$1
  local domain=$2
  local expected_target=${3:-""}

  echo -e "${YELLOW}Testing: $record_name${NC}"
  echo "Testing: $record_name" >> "$OUTPUT_FILE"
  echo "  Domain: $domain" >> "$OUTPUT_FILE"

  # Resolve DNS
  local resolved=$(resolve_dns "$domain")

  if [ "$resolved" = "RESOLUTION_FAILED" ] || [ -z "$resolved" ]; then
    echo -e "  ${RED}✗ DNS resolution failed${NC}"
    echo "  Status: FAILED - No DNS records found" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    return 1
  fi

  echo "  ✓ Resolved to: $resolved"
  echo "  Resolved IPs:" >> "$OUTPUT_FILE"

  # Display all resolved IPs
  while IFS= read -r ip; do
    echo "    - $ip" >> "$OUTPUT_FILE"
    echo "      $ip"
  done <<< "$resolved"

  # Check if resolution matches expected target
  if [ -n "$expected_target" ]; then
    # Resolve the expected target
    local expected_ips=$(resolve_dns "$expected_target")

    if echo "$resolved" | grep -q "$expected_target"; then
      echo -e "  ${GREEN}✓ Points to expected ALB: $expected_target${NC}"
      echo "  Expected Target: $expected_target (MATCHED)" >> "$OUTPUT_FILE"
    elif [ -n "$expected_ips" ] && echo "$resolved" | grep -qF "$expected_ips"; then
      echo -e "  ${GREEN}✓ Resolves to expected ALB IPs${NC}"
      echo "  Expected Target: $expected_target (IP MATCHED)" >> "$OUTPUT_FILE"
    else
      echo -e "  ${YELLOW}⚠ Does not match expected target: $expected_target${NC}"
      echo "  Expected Target: $expected_target (NOT MATCHED)" >> "$OUTPUT_FILE"
    fi
  fi

  echo "" >> "$OUTPUT_FILE"
  echo ""
}

##############################################################################
# Function: test_http_endpoint
# Tests HTTP endpoint and verifies response
##############################################################################
test_http_endpoint() {
  local name=$1
  local url=$2

  echo -e "${YELLOW}Testing HTTP endpoint: $name${NC}"
  echo "Testing HTTP endpoint: $name" >> "$OUTPUT_FILE"
  echo "  URL: $url" >> "$OUTPUT_FILE"

  # Make HTTP request
  local response=$(curl -s -w "\n%{http_code}" --max-time 5 "$url/health" 2>/dev/null || echo -e "\n000")
  local body=$(echo "$response" | head -n -1)
  local http_code=$(echo "$response" | tail -n 1)

  if [ "$http_code" = "200" ]; then
    echo -e "  ${GREEN}✓ HTTP 200 OK${NC}"
    echo "  Status: HTTP $http_code (SUCCESS)" >> "$OUTPUT_FILE"

    # Extract region from response if JSON
    if echo "$body" | grep -q '"region"'; then
      local region=$(echo "$body" | grep -o '"region":"[^"]*"' | cut -d'"' -f4)
      echo "  ✓ Serving from region: $region"
      echo "  Region: $region" >> "$OUTPUT_FILE"
    fi
  else
    echo -e "  ${RED}✗ HTTP $http_code${NC}"
    echo "  Status: HTTP $http_code (FAILED)" >> "$OUTPUT_FILE"
  fi

  echo "" >> "$OUTPUT_FILE"
  echo ""
}

##############################################################################
# Function: test_geolocation_routing
# Tests Route53 geolocation routing using external DNS checkers
##############################################################################
test_geolocation_routing() {
  local domain=$1

  echo -e "${BLUE}Geolocation Routing Test: $domain${NC}"
  echo "Geolocation Routing Test: $domain" >> "$OUTPUT_FILE"
  echo ""

  echo "To verify geolocation routing, use online DNS checkers:"
  echo "  - https://www.whatsmydns.net/#A/$domain"
  echo "  - https://dnschecker.org/#A/$domain"
  echo ""

  echo "Online DNS Checkers:" >> "$OUTPUT_FILE"
  echo "  - https://www.whatsmydns.net/#A/$domain" >> "$OUTPUT_FILE"
  echo "  - https://dnschecker.org/#A/$domain" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"

  echo "Expected routing behavior:"
  echo "  Korean resolvers    → Seoul ALB (ap-northeast-2)"
  echo "  US East resolvers   → US-East ALB (us-east-1)"
  echo "  US West resolvers   → US-West ALB (us-west-2)"
  echo "  Other locations     → Nearest ALB"
  echo ""

  echo "Expected routing behavior:" >> "$OUTPUT_FILE"
  echo "  Korean resolvers    → Seoul ALB (ap-northeast-2)" >> "$OUTPUT_FILE"
  echo "  US East resolvers   → US-East ALB (us-east-1)" >> "$OUTPUT_FILE"
  echo "  US West resolvers   → US-West ALB (us-west-2)" >> "$OUTPUT_FILE"
  echo "  Other locations     → Nearest ALB" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
}

##############################################################################
# Function: check_route53_health_checks
# Verifies Route53 health checks using AWS CLI
##############################################################################
check_route53_health_checks() {
  echo -e "${BLUE}Checking Route53 Health Checks...${NC}"
  echo "Route53 Health Checks:" >> "$OUTPUT_FILE"

  if ! command -v aws &> /dev/null; then
    echo -e "  ${YELLOW}⚠ AWS CLI not found - skipping health check verification${NC}"
    echo "  AWS CLI not available - skipped" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    return 0
  fi

  # Get hosted zone ID from terraform outputs
  local hosted_zone_id=""
  if [ -f "terraform/outputs.json" ]; then
    hosted_zone_id=$(cat terraform/outputs.json | grep -o '"hosted_zone_id"[^,]*' | cut -d'"' -f4 || echo "")
  fi

  if [ -z "$hosted_zone_id" ]; then
    echo -e "  ${YELLOW}⚠ Hosted zone ID not found - skipping${NC}"
    echo "  Hosted zone ID not configured - skipped" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    return 0
  fi

  # List health checks
  local health_checks=$(aws route53 list-health-checks --query 'HealthChecks[*].[Id,HealthCheckConfig.FullyQualifiedDomainName,HealthCheckConfig.Type]' --output text 2>/dev/null || echo "")

  if [ -n "$health_checks" ]; then
    echo "  ✓ Found Route53 health checks:"
    echo "$health_checks" | while IFS=$'\t' read -r id fqdn type; do
      echo "    - $fqdn ($type)"
      echo "    - $fqdn ($type) [ID: $id]" >> "$OUTPUT_FILE"
    done
  else
    echo -e "  ${YELLOW}⚠ No health checks configured${NC}"
    echo "  No health checks found" >> "$OUTPUT_FILE"
  fi

  echo "" >> "$OUTPUT_FILE"
  echo ""
}

##############################################################################
# Main execution
##############################################################################

echo "DNS Configuration:"
echo "  Global domain:  $GLOBAL_DOMAIN"
echo "  Seoul domain:   $SEOUL_DOMAIN"
echo "  US-East domain: $US_EAST_DOMAIN"
echo "  US-West domain: $US_WEST_DOMAIN"
echo ""

if [ -n "$SEOUL_ALB" ] && [ -n "$US_EAST_ALB" ] && [ -n "$US_WEST_ALB" ]; then
  echo "Expected ALB targets:"
  echo "  Seoul:   $SEOUL_ALB"
  echo "  US-East: $US_EAST_ALB"
  echo "  US-West: $US_WEST_ALB"
  echo ""
fi

echo "Configuration:" >> "$OUTPUT_FILE"
echo "  Global domain:  $GLOBAL_DOMAIN" >> "$OUTPUT_FILE"
echo "  Seoul domain:   $SEOUL_DOMAIN" >> "$OUTPUT_FILE"
echo "  US-East domain: $US_EAST_DOMAIN" >> "$OUTPUT_FILE"
echo "  US-West domain: $US_WEST_DOMAIN" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Test 1: Regional DNS records
echo "================================================"
echo "Test 1: Regional DNS Records"
echo "================================================"
echo ""

test_dns_record "Seoul Regional Endpoint" "$SEOUL_DOMAIN" "$SEOUL_ALB"
test_dns_record "US-East Regional Endpoint" "$US_EAST_DOMAIN" "$US_EAST_ALB"
test_dns_record "US-West Regional Endpoint" "$US_WEST_DOMAIN" "$US_WEST_ALB"

# Test 2: Global domain (geolocation routing)
echo "================================================"
echo "Test 2: Global Domain (Geolocation Routing)"
echo "================================================"
echo ""

test_dns_record "Global Endpoint" "$GLOBAL_DOMAIN"
test_geolocation_routing "$GLOBAL_DOMAIN"

# Test 3: HTTP endpoint verification
echo "================================================"
echo "Test 3: HTTP Endpoint Verification"
echo "================================================"
echo ""

# Test regional endpoints directly via ALB
if [ -n "$SEOUL_ALB" ]; then
  test_http_endpoint "Seoul ALB" "http://$SEOUL_ALB"
fi

if [ -n "$US_EAST_ALB" ]; then
  test_http_endpoint "US-East ALB" "http://$US_EAST_ALB"
fi

if [ -n "$US_WEST_ALB" ]; then
  test_http_endpoint "US-West ALB" "http://$US_WEST_ALB"
fi

# Test 4: Route53 health checks
echo "================================================"
echo "Test 4: Route53 Configuration"
echo "================================================"
echo ""

check_route53_health_checks

# Summary
echo "================================================"
echo "DNS Validation Summary"
echo "================================================"
echo ""
echo -e "${GREEN}✓ DNS validation complete${NC}"
echo "  Detailed results saved to: $OUTPUT_FILE"
echo ""
echo "Next steps:"
echo "  1. Verify geolocation routing using online DNS checkers"
echo "  2. Test from multiple geographic locations (VPN recommended)"
echo "  3. Check Route53 console for health check status"
echo ""

exit 0
