package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestRoute53HostedZoneCreation verifies that hosted zone is created with correct settings
func TestRoute53HostedZoneCreation(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../",
		Vars: map[string]interface{}{
			"project_name":          "hyundai-poc-test",
			"domain_name":           "test.hyundai-poc.com",
			"create_hosted_zone":    true,
			"seoul_alb_dns_name":    "seoul-alb-test.us-east-1.elb.amazonaws.com",
			"seoul_alb_zone_id":     "Z35SXDOTRQ7X7K",
			"us_east_alb_dns_name":  "us-east-alb-test.us-east-1.elb.amazonaws.com",
			"us_east_alb_zone_id":   "Z35SXDOTRQ7X7K",
			"us_west_alb_dns_name":  "us-west-alb-test.us-west-2.elb.amazonaws.com",
			"us_west_alb_zone_id":   "Z1H1FL5HABSF5",
		},
		NoColor: true,
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndPlan(t, terraformOptions)

	// Verify plan succeeds without errors
	planOutput := terraform.Plan(t, terraformOptions)
	assert.NotEmpty(t, planOutput)
}

// TestRoute53GeolocationRecords verifies that geolocation routing policies are configured correctly
func TestRoute53GeolocationRecords(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../",
		Vars: map[string]interface{}{
			"project_name":          "hyundai-poc-test",
			"domain_name":           "test.hyundai-poc.com",
			"create_hosted_zone":    true,
			"seoul_alb_dns_name":    "seoul-alb-test.ap-northeast-2.elb.amazonaws.com",
			"seoul_alb_zone_id":     "ZWKZPGTI48KDX",
			"us_east_alb_dns_name":  "us-east-alb-test.us-east-1.elb.amazonaws.com",
			"us_east_alb_zone_id":   "Z35SXDOTRQ7X7K",
			"us_west_alb_dns_name":  "us-west-alb-test.us-west-2.elb.amazonaws.com",
			"us_west_alb_zone_id":   "Z1H1FL5HABSF5",
			"cloudfront_domain_name": "d123456.cloudfront.net",
		},
		NoColor: true,
	}

	defer terraform.Destroy(t, terraformOptions)
	planOutput := terraform.InitAndPlan(t, terraformOptions)

	// Verify that geolocation records are planned
	assert.Contains(t, planOutput, "seoul.test.hyundai-poc.com")
	assert.Contains(t, planOutput, "us-east.test.hyundai-poc.com")
	assert.Contains(t, planOutput, "us-west.test.hyundai-poc.com")
	assert.Contains(t, planOutput, "www.test.hyundai-poc.com")
}

// TestRoute53HealthChecks verifies that health checks are configured for each regional ALB
func TestRoute53HealthChecks(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../",
		Vars: map[string]interface{}{
			"project_name":          "hyundai-poc-test",
			"domain_name":           "test.hyundai-poc.com",
			"create_hosted_zone":    false,
			"hosted_zone_id":        "Z1234567890ABC",
			"seoul_alb_dns_name":    "seoul-alb-test.ap-northeast-2.elb.amazonaws.com",
			"seoul_alb_zone_id":     "ZWKZPGTI48KDX",
			"us_east_alb_dns_name":  "us-east-alb-test.us-east-1.elb.amazonaws.com",
			"us_east_alb_zone_id":   "Z35SXDOTRQ7X7K",
			"us_west_alb_dns_name":  "us-west-alb-test.us-west-2.elb.amazonaws.com",
			"us_west_alb_zone_id":   "Z1H1FL5HABSF5",
			"health_check_path":     "/health",
			"health_check_interval": 30,
		},
		NoColor: true,
	}

	defer terraform.Destroy(t, terraformOptions)
	planOutput := terraform.InitAndPlan(t, terraformOptions)

	// Verify health checks are configured
	assert.Contains(t, planOutput, "aws_route53_health_check.seoul")
	assert.Contains(t, planOutput, "aws_route53_health_check.us_east")
	assert.Contains(t, planOutput, "aws_route53_health_check.us_west")
	assert.Contains(t, planOutput, "/health")
}

// TestRoute53OutputsAreValid verifies that module outputs are correctly configured
func TestRoute53OutputsAreValid(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../",
		Vars: map[string]interface{}{
			"project_name":          "hyundai-poc-test",
			"domain_name":           "test.hyundai-poc.com",
			"create_hosted_zone":    false,
			"hosted_zone_id":        "Z1234567890ABC",
			"seoul_alb_dns_name":    "seoul-alb.ap-northeast-2.elb.amazonaws.com",
			"seoul_alb_zone_id":     "ZWKZPGTI48KDX",
			"us_east_alb_dns_name":  "us-east-alb.us-east-1.elb.amazonaws.com",
			"us_east_alb_zone_id":   "Z35SXDOTRQ7X7K",
			"us_west_alb_dns_name":  "us-west-alb.us-west-2.elb.amazonaws.com",
			"us_west_alb_zone_id":   "Z1H1FL5HABSF5",
		},
		NoColor: true,
	}

	defer terraform.Destroy(t, terraformOptions)
	planOutput := terraform.InitAndPlan(t, terraformOptions)

	// Verify required outputs are defined
	assert.Contains(t, planOutput, "hosted_zone_id")
	assert.Contains(t, planOutput, "seoul_record_fqdn")
	assert.Contains(t, planOutput, "us_east_record_fqdn")
	assert.Contains(t, planOutput, "us_west_record_fqdn")
}
