# Route53 Module Tests

This directory contains automated tests for the Route53 Terraform module.

## Test Coverage

The tests verify the following functionality:

1. **Hosted Zone Creation** - Validates that hosted zone is created with correct settings when `create_hosted_zone = true`
2. **Geolocation Routing Policies** - Verifies that geolocation records point to the correct regional ALBs
3. **Health Checks** - Confirms health checks are configured for each regional ALB endpoint
4. **Module Outputs** - Validates that all required outputs are properly exposed

## Running Tests

### Prerequisites

```bash
# Install Go (if not already installed)
brew install go

# Install Terratest
go get github.com/gruntwork-io/terratest/modules/terraform
go get github.com/stretchr/testify/assert
```

### Execute Tests

```bash
# Navigate to tests directory
cd terraform/modules/route53/tests

# Run all tests
go test -v -timeout 30m

# Run specific test
go test -v -run TestRoute53HealthChecks -timeout 10m

# Run tests in parallel
go test -v -parallel 4 -timeout 30m
```

## Test Structure

Each test follows this pattern:

1. **Setup** - Define Terraform options with test variables
2. **Plan** - Execute `terraform init` and `terraform plan`
3. **Verify** - Assert expected resources are in the plan
4. **Cleanup** - Destroy resources (handled by defer)

## Manual Validation

For DNS propagation and geolocation routing, manual validation is required:

```bash
# Verify DNS resolution
dig seoul.hyundai-poc.com
dig us-east.hyundai-poc.com
dig us-west.hyundai-poc.com

# Test from different geographic locations
# Use online tools like whatsmydns.net or dnschecker.org

# Verify health checks
aws route53 get-health-check-status --health-check-id <health-check-id>
```

## Notes

- Tests use `terraform plan` only to avoid creating actual AWS resources
- DNS propagation tests are skipped as specified in requirements
- Full integration testing requires actual deployment and DNS propagation (5-10 minutes)
