# DNS Verification Guide

This guide provides step-by-step instructions for verifying Route53 DNS configuration and geolocation routing for the Hyundai Motors POC infrastructure.

## Prerequisites

- AWS CLI configured with appropriate credentials
- Access to the deployed infrastructure
- `dig` or `nslookup` command-line tools
- Optional: VPN or proxy for testing from different geographic locations

## Verification Steps

### 1. Verify Hosted Zone Creation

```bash
# List Route53 hosted zones
aws route53 list-hosted-zones --query 'HostedZones[?Name==`hyundai-poc.com.`]'

# Get hosted zone details
export HOSTED_ZONE_ID="Z1234567890ABC"  # Replace with your zone ID
aws route53 get-hosted-zone --id $HOSTED_ZONE_ID
```

**Expected Output:**
- Hosted zone exists with domain name `hyundai-poc.com`
- Name servers are listed (4 NS records)

### 2. Verify DNS Records

```bash
# List all DNS records in the hosted zone
aws route53 list-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID

# Filter for specific records
aws route53 list-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --query 'ResourceRecordSets[?Name==`seoul.hyundai-poc.com.`]'
```

**Expected Records:**
- `seoul.hyundai-poc.com` → Seoul ALB (Asia geolocation)
- `us-east.hyundai-poc.com` → US-East ALB (US geolocation)
- `us-west.hyundai-poc.com` → US-West ALB (US geolocation)
- `www.hyundai-poc.com` → CloudFront distribution (global)
- `api.hyundai-poc.com` → Default ALB (fallback)

### 3. Verify Health Checks

```bash
# List all health checks
aws route53 list-health-checks \
  --query 'HealthChecks[?HealthCheckConfig.FullyQualifiedDomainName!=`null`]'

# Get specific health check status
export HEALTH_CHECK_ID="abc123-def456-ghi789"  # Replace with your health check ID
aws route53 get-health-check-status --health-check-id $HEALTH_CHECK_ID
```

**Expected Output:**
- 3 health checks exist (Seoul, US-East, US-West)
- Each health check monitors `/health` endpoint
- Status shows "Healthy" for all checks
- Interval: 30 seconds

### 4. Test DNS Resolution

```bash
# Test DNS resolution for each regional endpoint
dig seoul.hyundai-poc.com
dig us-east.hyundai-poc.com
dig us-west.hyundai-poc.com
dig www.hyundai-poc.com

# Verify TTL is set to 60 seconds
dig seoul.hyundai-poc.com | grep "IN"

# Test with specific DNS server
dig @8.8.8.8 seoul.hyundai-poc.com
```

**Expected Output:**
- Each domain resolves to the correct ALB DNS name
- TTL = 60 seconds
- No NXDOMAIN errors

### 5. Verify Geolocation Routing

#### Using AWS CLI Test

```bash
# Test DNS resolution from different resolver IPs
# Note: This simulates but doesn't fully test geolocation routing

aws route53 test-dns-answer \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --record-name seoul.hyundai-poc.com \
  --record-type A \
  --resolver-ip 8.8.8.8
```

#### Using Online Tools

Visit these websites to verify DNS propagation globally:

1. **whatsmydns.net** - https://www.whatsmydns.net/
   - Enter: `seoul.hyundai-poc.com`
   - Select: A record
   - Verify: Resolution from different geographic locations

2. **dnschecker.org** - https://dnschecker.org/
   - Enter: `us-east.hyundai-poc.com`
   - Verify: Different regions resolve correctly

3. **DNS Propagation Checker** - https://www.dnswatch.info/
   - Verify all regional subdomains

#### Manual Geographic Testing

**From Asia (Korea, Japan, Singapore):**
```bash
# Should resolve to Seoul ALB
curl -I https://api.hyundai-poc.com/health
# Expected: X-Region: ap-northeast-2 (if header added)
```

**From US East Coast (Virginia, New York):**
```bash
# Should resolve to US-East ALB
curl -I https://api.hyundai-poc.com/health
# Expected: X-Region: us-east-1
```

**From US West Coast (California, Oregon):**
```bash
# Should resolve to US-West ALB
curl -I https://api.hyundai-poc.com/health
# Expected: X-Region: us-west-2
```

**Using VPN for Testing:**
```bash
# Connect VPN to Korean server
# Test DNS resolution
dig seoul.hyundai-poc.com

# Connect VPN to US server
# Test DNS resolution
dig us-east.hyundai-poc.com
```

### 6. Verify CloudFront Distribution

```bash
# Test CloudFront domain directly
curl -I https://d123456.cloudfront.net/

# Test via Route53 www record
dig www.hyundai-poc.com
curl -I https://www.hyundai-poc.com/

# Verify caching headers
curl -I https://www.hyundai-poc.com/_next/static/css/styles.css
# Expected: X-Cache: Hit from cloudfront (after first request)
```

### 7. Measure Latency from Current Location

```bash
# Create a simple latency test script
cat > test-latency.sh << 'EOF'
#!/bin/bash
echo "Testing latency to all regional endpoints..."
echo ""

for endpoint in seoul.hyundai-poc.com us-east.hyundai-poc.com us-west.hyundai-poc.com; do
  echo "Testing $endpoint:"
  time curl -s -o /dev/null -w "HTTP Status: %{http_code}\nTime: %{time_total}s\n" https://$endpoint/health
  echo ""
done
EOF

chmod +x test-latency.sh
./test-latency.sh
```

**Expected Results:**
- Fastest response from geographically nearest region
- Korea → Seoul: <50ms
- Korea → US-East: 150-200ms
- Korea → US-West: 100-150ms

### 8. Verify Failover Behavior

```bash
# Monitor health check status
watch -n 5 'aws route53 get-health-check-status --health-check-id $HEALTH_CHECK_ID'

# Simulate ALB failure (stop ECS tasks or modify security group)
# Verify health check transitions to "Unhealthy"
# Verify DNS still resolves (Routes to healthy region)
```

### 9. Check Route53 Query Logging (Optional)

```bash
# Enable query logging
aws route53 create-query-logging-config \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --cloud-watch-logs-log-group-arn arn:aws:logs:us-east-1:123456789012:log-group:/aws/route53/hyundai-poc

# View query logs
aws logs tail /aws/route53/hyundai-poc --follow
```

## Troubleshooting

### DNS Not Resolving

```bash
# Check hosted zone name servers match domain registrar
aws route53 get-hosted-zone --id $HOSTED_ZONE_ID --query 'DelegationSet.NameServers'

# Verify domain registrar NS records match Route53
# Update domain registrar if necessary
```

### Geolocation Routing Not Working

```bash
# Verify geolocation policies are set
aws route53 list-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID \
  --query 'ResourceRecordSets[?GeoLocation!=`null`]'

# Check set identifiers are unique
# Verify default geolocation policy exists
```

### Health Checks Failing

```bash
# Check ALB is accessible
curl -I http://<alb-dns-name>/health

# Verify security groups allow Route53 health checkers
# Route53 health checker IP ranges: https://ip-ranges.amazonaws.com/ip-ranges.json
# Filter for "ROUTE53_HEALTHCHECKS" service

# Check ALB target group health
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>
```

### CloudFront Not Caching

```bash
# Check cache behavior configuration
aws cloudfront get-distribution-config --id <distribution-id>

# Verify cache policy settings
# Clear CloudFront cache if needed
aws cloudfront create-invalidation \
  --distribution-id <distribution-id> \
  --paths "/*"
```

## Validation Checklist

Use this checklist during interview demonstration:

- [ ] Hosted zone exists with correct domain name
- [ ] All DNS records created (seoul, us-east, us-west, www, api)
- [ ] All 3 health checks showing "Healthy" status
- [ ] DNS resolution works for all subdomains
- [ ] Geolocation routing confirmed from multiple locations
- [ ] CloudFront distribution serving content
- [ ] Latency measurements show expected geographic differences
- [ ] Failover behavior verified (optional, time permitting)

## Performance Benchmarks

Document these metrics for interview presentation:

| Source Location | Target Region | Latency (ms) | Status |
|----------------|---------------|--------------|--------|
| Seoul          | Seoul ALB     | <50          | ✓      |
| Seoul          | US-East ALB   | 150-200      | ✓      |
| Seoul          | US-West ALB   | 100-150      | ✓      |
| US-East        | US-East ALB   | <10          | ✓      |
| US-West        | US-West ALB   | <10          | ✓      |

## References

- [AWS Route53 Documentation](https://docs.aws.amazon.com/route53/)
- [Route53 Health Checks](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-failover.html)
- [Geolocation Routing](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy-geo.html)
- [CloudFront Distribution Configuration](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/)
