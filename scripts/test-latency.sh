#!/bin/bash

##############################################################################
# Latency Measurement Validation Script
#
# Purpose: Measure latency from current location to all 3 regional ALB endpoints
# Author: Hyundai Motors POC Team
# Usage: ./scripts/test-latency.sh
#
# This script:
# - Executes 10 consecutive requests per region
# - Calculates average, min, max, P95 latency
# - Outputs results to console and CSV file
##############################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "================================================"
echo "Hyundai Motors POC - Latency Measurement Test"
echo "================================================"
echo ""

# Regional endpoints - read from terraform outputs or environment variables
SEOUL_ENDPOINT="${SEOUL_ENDPOINT:-}"
US_EAST_ENDPOINT="${US_EAST_ENDPOINT:-}"
US_WEST_ENDPOINT="${US_WEST_ENDPOINT:-}"

# Load from terraform outputs if not set
if [ -z "$SEOUL_ENDPOINT" ] || [ -z "$US_EAST_ENDPOINT" ] || [ -z "$US_WEST_ENDPOINT" ]; then
  if [ -f "terraform/outputs.json" ]; then
    echo "Loading endpoints from terraform outputs..."
    SEOUL_ENDPOINT=$(cat terraform/outputs.json | grep -o '"seoul_alb_dns"[^,]*' | cut -d'"' -f4 || echo "")
    US_EAST_ENDPOINT=$(cat terraform/outputs.json | grep -o '"us_east_alb_dns"[^,]*' | cut -d'"' -f4 || echo "")
    US_WEST_ENDPOINT=$(cat terraform/outputs.json | grep -o '"us_west_alb_dns"[^,]*' | cut -d'"' -f4 || echo "")
  fi
fi

# Validate endpoints are configured
if [ -z "$SEOUL_ENDPOINT" ] || [ -z "$US_EAST_ENDPOINT" ] || [ -z "$US_WEST_ENDPOINT" ]; then
  echo -e "${RED}ERROR: Regional endpoints not configured${NC}"
  echo "Please set environment variables or ensure terraform/outputs.json exists:"
  echo "  SEOUL_ENDPOINT"
  echo "  US_EAST_ENDPOINT"
  echo "  US_WEST_ENDPOINT"
  exit 1
fi

echo "Testing endpoints:"
echo "  Seoul (ap-northeast-2): $SEOUL_ENDPOINT"
echo "  US-East (us-east-1):    $US_EAST_ENDPOINT"
echo "  US-West (us-west-2):    $US_WEST_ENDPOINT"
echo ""

# Number of iterations per endpoint
ITERATIONS=10

# Output file
OUTPUT_DIR="test-results"
mkdir -p "$OUTPUT_DIR"
OUTPUT_FILE="$OUTPUT_DIR/latency-baseline.csv"

# Initialize CSV file
echo "Region,Endpoint,Iteration,Latency_ms,Status" > "$OUTPUT_FILE"

##############################################################################
# Function: measure_latency
# Measures HTTP latency to a given endpoint
##############################################################################
measure_latency() {
  local region=$1
  local endpoint=$2
  local url="http://${endpoint}/health"

  echo -e "${YELLOW}Testing $region ($endpoint)...${NC}"

  local measurements=()
  local successful=0
  local failed=0

  for i in $(seq 1 $ITERATIONS); do
    # Measure latency using curl with time output
    local start_time=$(date +%s%N)
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null || echo "000")
    local end_time=$(date +%s%N)

    if [ "$http_code" = "200" ]; then
      local latency=$(( ($end_time - $start_time) / 1000000 ))
      measurements+=($latency)
      successful=$((successful + 1))
      echo "  Request $i: ${latency}ms (HTTP $http_code)"
      echo "$region,$endpoint,$i,$latency,success" >> "$OUTPUT_FILE"
    else
      failed=$((failed + 1))
      echo -e "  Request $i: ${RED}Failed (HTTP $http_code)${NC}"
      echo "$region,$endpoint,$i,,-1,failed" >> "$OUTPUT_FILE"
    fi

    # Small delay between requests
    sleep 0.1
  done

  # Calculate statistics
  if [ ${#measurements[@]} -gt 0 ]; then
    # Sort measurements
    IFS=$'\n' sorted=($(sort -n <<<"${measurements[*]}"))
    unset IFS

    # Calculate average
    local sum=0
    for val in "${measurements[@]}"; do
      sum=$((sum + val))
    done
    local average=$((sum / ${#measurements[@]}))

    # Get min, max
    local min=${sorted[0]}
    local max=${sorted[-1]}

    # Calculate P95
    local p95_index=$(( ${#sorted[@]} * 95 / 100 ))
    local p95=${sorted[$p95_index]}

    echo ""
    echo -e "${GREEN}Statistics for $region:${NC}"
    echo "  Successful: $successful / $ITERATIONS"
    echo "  Average:    ${average}ms"
    echo "  Min:        ${min}ms"
    echo "  Max:        ${max}ms"
    echo "  P95:        ${p95}ms"
    echo ""

    # Write summary to CSV
    echo "$region,$endpoint,summary_avg,$average,success" >> "$OUTPUT_FILE"
    echo "$region,$endpoint,summary_min,$min,success" >> "$OUTPUT_FILE"
    echo "$region,$endpoint,summary_max,$max,success" >> "$OUTPUT_FILE"
    echo "$region,$endpoint,summary_p95,$p95,success" >> "$OUTPUT_FILE"

    # Return average for comparison
    echo $average
  else
    echo -e "${RED}All requests failed for $region${NC}"
    echo ""
    return 1
  fi
}

##############################################################################
# Main execution
##############################################################################

echo "Starting latency measurements (${ITERATIONS} iterations per region)..."
echo ""

# Measure latency for each region
seoul_avg=$(measure_latency "Seoul" "$SEOUL_ENDPOINT" || echo "-1")
us_east_avg=$(measure_latency "US-East" "$US_EAST_ENDPOINT" || echo "-1")
us_west_avg=$(measure_latency "US-West" "$US_WEST_ENDPOINT" || echo "-1")

echo "================================================"
echo "Latency Measurement Summary"
echo "================================================"
echo ""

# Display results with color coding
if [ "$seoul_avg" != "-1" ]; then
  if [ $seoul_avg -lt 50 ]; then
    echo -e "Seoul (ap-northeast-2):   ${GREEN}${seoul_avg}ms (✓ < 50ms)${NC}"
  else
    echo -e "Seoul (ap-northeast-2):   ${YELLOW}${seoul_avg}ms (⚠ >= 50ms)${NC}"
  fi
else
  echo -e "Seoul (ap-northeast-2):   ${RED}Failed${NC}"
fi

if [ "$us_east_avg" != "-1" ]; then
  if [ $us_east_avg -ge 150 ] && [ $us_east_avg -le 200 ]; then
    echo -e "US-East (us-east-1):      ${GREEN}${us_east_avg}ms (✓ 150-200ms)${NC}"
  else
    echo -e "US-East (us-east-1):      ${YELLOW}${us_east_avg}ms (⚠ outside 150-200ms)${NC}"
  fi
else
  echo -e "US-East (us-east-1):      ${RED}Failed${NC}"
fi

if [ "$us_west_avg" != "-1" ]; then
  if [ $us_west_avg -ge 100 ] && [ $us_west_avg -le 150 ]; then
    echo -e "US-West (us-west-2):      ${GREEN}${us_west_avg}ms (✓ 100-150ms)${NC}"
  else
    echo -e "US-West (us-west-2):      ${YELLOW}${us_west_avg}ms (⚠ outside 100-150ms)${NC}"
  fi
else
  echo -e "US-West (us-west-2):      ${RED}Failed${NC}"
fi

echo ""
echo "Detailed results saved to: $OUTPUT_FILE"
echo ""

# Expected results note
echo "================================================"
echo "Expected Results (when running from Korea):"
echo "================================================"
echo "  Seoul:   < 50ms (same region, low latency)"
echo "  US-East: 150-200ms (cross-region, high latency)"
echo "  US-West: 100-150ms (cross-region, moderate latency)"
echo ""
echo "Note: Actual latency depends on your current geographic location."
echo "      These targets are calibrated for requests originating from Korea."
echo ""

exit 0
