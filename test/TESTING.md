# Testing Guide - Hyundai Motors POC

This document provides a quick reference for running all tests in the Hyundai Motors Infrastructure POC.

## Test Overview

**Total Test Count:** 34-40 tests
- Existing tests from Task Groups 2-6: ~24-30 tests
- New integration tests: 10 tests

**Coverage:** All 4 core validation objectives

## Quick Start

### 1. Run Integration Tests

```bash
cd test/integration
npm install
npm test
```

**Prerequisites:**
- Infrastructure deployed and healthy
- Environment variables set (SEOUL_ENDPOINT, US_EAST_ENDPOINT, US_WEST_ENDPOINT)

### 2. Run Validation Scripts

```bash
# Measure latency (outputs to test-results/latency-baseline.csv)
./scripts/test-latency.sh

# Test replication lag (outputs to test-results/replication-baseline.csv)
./scripts/test-replication.sh

# Validate DNS routing (outputs to test-results/dns-validation.txt)
./scripts/test-dns.sh
```

## Test Categories

### Integration Tests (10 tests)
**Location:** `test/integration/end-to-end.test.js`

1. **Latency Measurement (3 tests)**
   - Korea-to-Korea < 50ms
   - Korea-to-US-East 150-200ms
   - Korea-to-US-West 100-150ms

2. **Replication Lag (2 tests)**
   - Aurora replication lag < 1000ms
   - Write-read consistency

3. **Failover Capability (1 test)**
   - All regional health endpoints

4. **DNS Routing (2 tests)**
   - Route53 geolocation routing
   - Metrics endpoint includes all regions

5. **Observability (2 tests)**
   - Database health check
   - Metrics structure validation

### Validation Scripts (3 scripts)

1. **test-latency.sh**
   - 10 iterations per region
   - Calculates avg, min, max, P95
   - Output: CSV report

2. **test-replication.sh**
   - 5 write-read cycles
   - Measures replication lag
   - Output: CSV report with P50, P95

3. **test-dns.sh**
   - DNS resolution verification
   - HTTP endpoint testing
   - Output: Text report

## Validation Objectives

| Objective | Tests | Scripts | Status |
|-----------|-------|---------|--------|
| Regional Latency | 3 | test-latency.sh | ✅ |
| Replication Lag | 2 | test-replication.sh | ✅ |
| Failover Capability | 1 | Runbook in docs/ | ✅ |
| DNS Routing | 2 | test-dns.sh | ✅ |

## Running Existing Tests

### Backend API Tests
```bash
cd application/backend
npm test
```

### Frontend Component Tests
```bash
cd application/frontend
npm test
```

## Documentation

- **Integration Tests:** `test/integration/README.md`
- **Failover Procedure:** `docs/failover-runbook.md`
- **Final Report:** `test-results/final-report.md`
- **Coverage Analysis:** `test-results/test-coverage-analysis.md`

## Troubleshooting

**Tests timeout:**
- Check infrastructure is deployed
- Verify ECS services are healthy
- Confirm security groups allow traffic

**Scripts fail:**
- Set environment variables (SEOUL_ENDPOINT, etc.)
- Check AWS CLI is configured
- Verify database credentials

**DNS tests fail:**
- Wait 60 seconds for DNS propagation
- Use ALB DNS names if custom domain not configured
- Check Route53 configuration in AWS console

## Next Steps

1. Deploy infrastructure with `terraform apply`
2. Run all tests to validate deployment
3. Execute validation scripts for baseline metrics
4. Fill in test-results/final-report.md with actual results
5. Take screenshots for interview
6. Review docs/failover-runbook.md for failover procedure

---

For detailed documentation, see:
- `test/integration/README.md` - Complete integration test guide
- `test-results/test-coverage-analysis.md` - Coverage analysis
