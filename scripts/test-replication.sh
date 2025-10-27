#!/bin/bash

##############################################################################
# Aurora Replication Lag Validation Script
#
# Purpose: Test Aurora Global Database replication lag
# Author: Hyundai Motors POC Team
# Usage: ./scripts/test-replication.sh
#
# This script:
# - Executes 5 write-read cycles
# - Writes timestamped record to primary (us-east-1)
# - Queries read replica (Seoul) for the same record
# - Measures time to first successful read
# - Calculates P50, P95 replication lag
##############################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "================================================"
echo "Hyundai Motors POC - Replication Lag Test"
echo "================================================"
echo ""

# Database connection parameters
DB_WRITER_HOST="${DB_WRITER_HOST:-}"
DB_READER_HOST="${DB_READER_HOST:-}"
DB_PORT="${DB_PORT:-3306}"
DB_NAME="${DB_NAME:-hyundai_poc}"
DB_USER="${DB_USER:-admin}"
DB_PASSWORD="${DB_PASSWORD:-}"

# Load from terraform outputs or environment
if [ -z "$DB_WRITER_HOST" ] || [ -z "$DB_READER_HOST" ]; then
  if [ -f "terraform/outputs.json" ]; then
    echo "Loading database endpoints from terraform outputs..."
    DB_WRITER_HOST=$(cat terraform/outputs.json | grep -o '"aurora_writer_endpoint"[^,]*' | cut -d'"' -f4 || echo "")
    DB_READER_HOST=$(cat terraform/outputs.json | grep -o '"aurora_reader_endpoint_seoul"[^,]*' | cut -d'"' -f4 || echo "")
  fi
fi

# Load password from AWS Secrets Manager if not set
if [ -z "$DB_PASSWORD" ]; then
  if command -v aws &> /dev/null; then
    echo "Loading database password from Secrets Manager..."
    DB_PASSWORD=$(aws secretsmanager get-secret-value \
      --secret-id hyundai-poc/db-password \
      --query SecretString \
      --output text 2>/dev/null || echo "")
  fi
fi

# Validate configuration
if [ -z "$DB_WRITER_HOST" ] || [ -z "$DB_READER_HOST" ] || [ -z "$DB_PASSWORD" ]; then
  echo -e "${RED}ERROR: Database connection parameters not configured${NC}"
  echo "Please set environment variables:"
  echo "  DB_WRITER_HOST"
  echo "  DB_READER_HOST"
  echo "  DB_PASSWORD"
  exit 1
fi

echo "Database configuration:"
echo "  Writer (Primary):  $DB_WRITER_HOST"
echo "  Reader (Seoul):    $DB_READER_HOST"
echo "  Database:          $DB_NAME"
echo "  User:              $DB_USER"
echo ""

# Check if mysql client is installed
if ! command -v mysql &> /dev/null; then
  echo -e "${RED}ERROR: mysql client not found${NC}"
  echo "Please install MySQL client:"
  echo "  macOS:  brew install mysql-client"
  echo "  Linux:  apt-get install mysql-client or yum install mysql"
  exit 1
fi

# Number of write-read cycles
CYCLES=5
MAX_RETRIES=10
RETRY_DELAY_MS=100

# Output file
OUTPUT_DIR="test-results"
mkdir -p "$OUTPUT_DIR"
OUTPUT_FILE="$OUTPUT_DIR/replication-baseline.csv"

# Initialize CSV file
echo "Cycle,Write_Timestamp,Record_ID,Replication_Lag_ms,Status" > "$OUTPUT_FILE"

##############################################################################
# Function: execute_write_read_cycle
# Writes to primary and measures replication lag to replica
##############################################################################
execute_write_read_cycle() {
  local cycle=$1
  local test_data="replication-test-${cycle}-$(date +%s%N)"

  echo -e "${YELLOW}Cycle $cycle: Testing write-read replication...${NC}"

  # Write to primary database
  local write_timestamp=$(date +%s%N)
  local write_sql="INSERT INTO health_checks (region, timestamp, replication_lag_ms) VALUES ('test-write', NOW(6), NULL);"

  local insert_result=$(mysql -h "$DB_WRITER_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" \
    -e "$write_sql; SELECT LAST_INSERT_ID();" -s -N 2>/dev/null || echo "ERROR")

  if [ "$insert_result" = "ERROR" ] || [ -z "$insert_result" ]; then
    echo -e "  ${RED}✗ Failed to write to primary database${NC}"
    echo "$cycle,$(date -u +%Y-%m-%dT%H:%M:%S),-1,-1,write_failed" >> "$OUTPUT_FILE"
    return 1
  fi

  local record_id=$(echo "$insert_result" | tail -1)
  echo "  ✓ Wrote record ID: $record_id to primary"

  # Query read replica with retries
  local replication_lag_ms=-1
  local found=false

  for retry in $(seq 0 $MAX_RETRIES); do
    local read_timestamp=$(date +%s%N)
    local read_sql="SELECT id FROM health_checks WHERE id = $record_id LIMIT 1;"

    local read_result=$(mysql -h "$DB_READER_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" \
      -e "$read_sql" -s -N 2>/dev/null || echo "")

    if [ -n "$read_result" ]; then
      # Record found - calculate replication lag
      replication_lag_ms=$(( ($read_timestamp - $write_timestamp) / 1000000 ))
      found=true
      echo -e "  ✓ Record replicated to Seoul in ${GREEN}${replication_lag_ms}ms${NC} (attempt $((retry + 1)))"
      break
    fi

    # Not found yet - wait and retry
    if [ $retry -lt $MAX_RETRIES ]; then
      sleep 0.$(printf "%03d" $RETRY_DELAY_MS)
    fi
  done

  if [ "$found" = false ]; then
    echo -e "  ${RED}✗ Record not replicated after ${MAX_RETRIES} retries (> 1000ms)${NC}"
    echo "$cycle,$(date -u +%Y-%m-%dT%H:%M:%S),$record_id,-1,replication_timeout" >> "$OUTPUT_FILE"
    return 1
  fi

  # Write result to CSV
  echo "$cycle,$(date -u +%Y-%m-%dT%H:%M:%S),$record_id,$replication_lag_ms,success" >> "$OUTPUT_FILE"

  # Return replication lag for statistics
  echo $replication_lag_ms
}

##############################################################################
# Main execution
##############################################################################

echo "Starting replication lag tests (${CYCLES} write-read cycles)..."
echo ""

# Execute write-read cycles
lag_measurements=()
successful=0
failed=0

for cycle in $(seq 1 $CYCLES); do
  lag=$(execute_write_read_cycle $cycle || echo "-1")

  if [ "$lag" != "-1" ]; then
    lag_measurements+=($lag)
    successful=$((successful + 1))
  else
    failed=$((failed + 1))
  fi

  echo ""

  # Small delay between cycles
  sleep 1
done

echo "================================================"
echo "Replication Lag Test Summary"
echo "================================================"
echo ""

# Calculate statistics
if [ ${#lag_measurements[@]} -gt 0 ]; then
  # Sort measurements
  IFS=$'\n' sorted=($(sort -n <<<"${lag_measurements[*]}"))
  unset IFS

  # Calculate average
  sum=0
  for val in "${lag_measurements[@]}"; do
    sum=$((sum + val))
  done
  average=$((sum / ${#lag_measurements[@]}))

  # Get min, max
  min=${sorted[0]}
  max=${sorted[-1]}

  # Calculate P50 (median)
  p50_index=$(( ${#sorted[@]} / 2 ))
  p50=${sorted[$p50_index]}

  # Calculate P95
  p95_index=$(( ${#sorted[@]} * 95 / 100 ))
  p95=${sorted[$p95_index]}

  echo "Test Results:"
  echo "  Successful cycles: $successful / $CYCLES"
  echo "  Failed cycles:     $failed / $CYCLES"
  echo ""
  echo "Replication Lag Statistics:"
  echo "  Average:  ${average}ms"
  echo "  Min:      ${min}ms"
  echo "  Max:      ${max}ms"
  echo "  P50:      ${p50}ms"

  if [ $p95 -lt 1000 ]; then
    echo -e "  P95:      ${GREEN}${p95}ms (✓ < 1000ms)${NC}"
  else
    echo -e "  P95:      ${RED}${p95}ms (✗ >= 1000ms)${NC}"
  fi

  echo ""
  echo "Detailed results saved to: $OUTPUT_FILE"
  echo ""

  # Write summary to CSV
  echo "summary,average,-1,$average,calculated" >> "$OUTPUT_FILE"
  echo "summary,min,-1,$min,calculated" >> "$OUTPUT_FILE"
  echo "summary,max,-1,$max,calculated" >> "$OUTPUT_FILE"
  echo "summary,p50,-1,$p50,calculated" >> "$OUTPUT_FILE"
  echo "summary,p95,-1,$p95,calculated" >> "$OUTPUT_FILE"

  # Expected results
  echo "================================================"
  echo "Expected Results:"
  echo "================================================"
  echo "  P95 replication lag: < 1000ms"
  echo "  Average replication lag: < 500ms (excellent)"
  echo ""

  # Exit with success if P95 < 1000ms
  if [ $p95 -lt 1000 ]; then
    echo -e "${GREEN}✓ Replication lag validation PASSED${NC}"
    exit 0
  else
    echo -e "${RED}✗ Replication lag validation FAILED${NC}"
    exit 1
  fi
else
  echo -e "${RED}All replication tests failed${NC}"
  echo ""
  echo "Detailed results saved to: $OUTPUT_FILE"
  exit 1
fi
