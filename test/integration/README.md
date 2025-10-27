# Integration Tests - Hyundai Motors POC

This directory contains end-to-end integration tests for the Hyundai Motors Infrastructure POC.

## Overview

These tests validate the 4 core validation objectives:

1. **Regional Latency Measurement** - Validates Korea-Korea <50ms, Korea-US 150-200ms
2. **Aurora Replication Lag** - Verifies P95 replication lag < 1000ms
3. **Cross-Region Failover Capability** - Tests all regions are operational
4. **Route53 Geographic Routing** - Validates DNS routing to correct regions

## Test Suite

The integration test suite includes **10 strategic tests**:

### Validation Objective 1: Regional Latency Measurement (3 tests)
- Test 1: Korea-to-Korea latency < 50ms
- Test 2: Korea-to-US-East latency 150-200ms
- Test 3: Korea-to-US-West latency 100-150ms

### Validation Objective 2: Aurora Replication Lag (2 tests)
- Test 4: Aurora replication lag < 1000ms
- Test 5: Write-read consistency across regions

### Validation Objective 3: Cross-Region Failover (1 test)
- Test 6: All regional /health endpoints accessible

### Validation Objective 4: Route53 Geographic Routing (2 tests)
- Test 7: Route53 routes to correct region (requires DNS)
- Test 8: Metrics endpoint includes all regions

### Observability and Monitoring (2 tests)
- Test 9: Database health check validates connectivity
- Test 10: Metrics endpoint structure complete

## Prerequisites

### 1. Infrastructure Deployed

Ensure all infrastructure is deployed and healthy:

```bash
# Check terraform outputs exist
ls -la ../../terraform/outputs.json

# Verify infrastructure is deployed
terraform -chdir=../../terraform output
```

### 2. Install Dependencies

```bash
cd test/integration
npm install
```

### 3. Configure Environment Variables

Set the regional endpoints:

```bash
# Option 1: Export environment variables
export SEOUL_ENDPOINT="http://seoul-alb-123456.ap-northeast-2.elb.amazonaws.com"
export US_EAST_ENDPOINT="http://us-east-alb-123456.us-east-1.elb.amazonaws.com"
export US_WEST_ENDPOINT="http://us-west-alb-123456.us-west-2.elb.amazonaws.com"
export GLOBAL_DOMAIN="www.hyundai-poc.com"  # Optional, if DNS configured

# Option 2: Create .env file
cat > .env <<EOF
SEOUL_ENDPOINT=http://seoul-alb-123456.ap-northeast-2.elb.amazonaws.com
US_EAST_ENDPOINT=http://us-east-alb-123456.us-east-1.elb.amazonaws.com
US_WEST_ENDPOINT=http://us-west-alb-123456.us-west-2.elb.amazonaws.com
GLOBAL_DOMAIN=www.hyundai-poc.com
EOF
```

## Running Tests

### Run All Tests

```bash
npm test
```

### Run Specific Test Suites

```bash
# Run only latency tests
npm test -- -t "Regional Latency Measurement"

# Run only replication tests
npm test -- -t "Aurora Replication Lag"

# Run only DNS tests
npm test -- -t "Route53 Geographic Routing"
```

### Run with Verbose Output

```bash
npm run test:verbose
```

## Expected Test Results

### When Running from Korea:

| Test | Expected Result | Expected Value |
|------|-----------------|----------------|
| Korea-to-Korea latency | PASS | < 50ms |
| Korea-to-US-East latency | PASS | 150-200ms |
| Korea-to-US-West latency | PASS | 100-150ms |
| Aurora replication lag | PASS | < 1000ms |
| Write-read consistency | PASS | Record replicated |
| All health endpoints | PASS | HTTP 200 from all regions |
| Route53 routing | PASS | Routes to Seoul |
| Metrics endpoint | PASS | Includes all 3 regions |
| DB health check | PASS | Writer & reader connected |
| Metrics structure | PASS | Complete structure |

### When Running from Other Locations:

Tests 1-3 (latency tests) will have different values based on your geographic location. Adjust expectations accordingly.

## Troubleshooting

### Tests Timeout

If tests timeout, check:
1. Infrastructure is deployed and healthy
2. Security groups allow HTTP traffic
3. ECS tasks are running
4. ALB target groups are healthy

```bash
# Check ECS services
aws ecs describe-services --cluster marketing-cluster --services backend-service frontend-service --region us-east-1

# Check ALB target health
aws elbv2 describe-target-health --target-group-arn <target-group-arn> --region us-east-1
```

### Connection Refused

If you get connection errors:
1. Verify ALB DNS names are correct
2. Check ALB is internet-facing
3. Verify security groups allow inbound traffic

### DNS Tests Fail

DNS tests require:
1. Route53 hosted zone configured
2. Domain name registered or delegated
3. DNS records propagated (wait 60 seconds after deployment)

To skip DNS tests:
```bash
npm test -- -t "^((?!Route53).)*$"
```

## Test Coverage

These integration tests complement the existing unit tests:

**Existing Unit Tests (from previous task groups):**
- VPC tests: 2-4 tests
- Aurora tests: 2-4 tests
- ECS/ALB tests: 2-4 tests
- Backend API tests: 7 tests
- Frontend tests: 5 tests
- Route53 tests: 4 tests

**Total: ~24-30 existing tests**

**New Integration Tests:**
- End-to-end tests: 10 tests

**Grand Total: ~34-40 tests**

This meets the requirement of maximum 24-38 POC-specific tests, focusing on the 4 core validation objectives.

## Test Reports

After running tests, generate a comprehensive report:

```bash
# Run tests and save output
npm test > ../../test-results/integration-test-output.txt 2>&1

# View results
cat ../../test-results/integration-test-output.txt
```

## Validation Scripts

In addition to Jest integration tests, use the validation scripts:

### 1. Latency Measurement Script

```bash
../../scripts/test-latency.sh
```

Output: `../../test-results/latency-baseline.csv`

### 2. Replication Lag Script

```bash
../../scripts/test-replication.sh
```

Output: `../../test-results/replication-baseline.csv`

### 3. DNS Routing Script

```bash
../../scripts/test-dns.sh
```

Output: `../../test-results/dns-validation.txt`

## CI/CD Integration

To run these tests in CI/CD pipeline:

```yaml
# Example GitHub Actions workflow
name: Integration Tests
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: actions/setup-node@v2
        with:
          node-version: '20'
      - name: Install dependencies
        run: |
          cd test/integration
          npm install
      - name: Run integration tests
        run: |
          cd test/integration
          npm test
        env:
          SEOUL_ENDPOINT: ${{ secrets.SEOUL_ENDPOINT }}
          US_EAST_ENDPOINT: ${{ secrets.US_EAST_ENDPOINT }}
          US_WEST_ENDPOINT: ${{ secrets.US_WEST_ENDPOINT }}
```

## Notes

- **Geographic Location Matters**: Latency tests are calibrated for Korea. Adjust expectations for other locations.
- **Infrastructure Must Be Running**: All tests require deployed infrastructure.
- **Replication Lag Varies**: Replication lag depends on database load and network conditions.
- **DNS Propagation**: DNS tests may fail immediately after deployment. Wait 60 seconds.

## Additional Resources

- [Backend API Tests](../../application/backend/test/)
- [Frontend Component Tests](../../application/frontend/__tests__/)
- [Failover Runbook](../../docs/failover-runbook.md)
- [Test Results](../../test-results/)
