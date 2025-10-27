# Aurora Global Database Failover Runbook

## Overview

This runbook provides step-by-step instructions for performing a manual cross-region failover of the Aurora Global Database from the primary region (us-east-1) to a secondary region (us-west-2 or ap-northeast-2).

**Use Case:** Disaster recovery, regional outage, or planned maintenance

**Expected RTO:** 3-5 minutes

**Expected RPO:** < 1 second (replication lag)

---

## Prerequisites

Before executing failover:

- [ ] AWS CLI installed and configured with appropriate credentials
- [ ] Access to AWS account with RDS and Route53 permissions
- [ ] Database connection credentials available
- [ ] Backup of current configuration documented
- [ ] Team notification sent (if applicable)
- [ ] Maintenance window scheduled (if applicable)

---

## Failover Scenarios

### Scenario A: Promote US-West-2 to Primary

Use when: US-East-1 region has an outage or requires maintenance

**Target Region:** us-west-2
**New Primary:** us-west-2
**Remaining Secondaries:** ap-northeast-2

### Scenario B: Promote Seoul (AP-Northeast-2) to Primary

Use when: Both US regions have issues or to optimize for Asia-Pacific traffic

**Target Region:** ap-northeast-2
**New Primary:** ap-northeast-2
**Remaining Secondaries:** us-west-2

---

## Pre-Failover Checklist

### 1. Verify Current State

```bash
# Get current global cluster configuration
aws rds describe-global-clusters \
  --global-cluster-identifier marketing-global \
  --query 'GlobalClusters[0]' \
  --output json

# Identify current primary (IsWriter=true)
aws rds describe-global-clusters \
  --global-cluster-identifier marketing-global \
  --query 'GlobalClusters[0].GlobalClusterMembers[?IsWriter==`true`]' \
  --output table
```

**Expected Output:**
- Current primary should be in us-east-1
- Two secondaries in ap-northeast-2 and us-west-2

### 2. Check Replication Lag

```bash
# Check replication lag for all secondary regions
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name AuroraGlobalDBReplicationLag \
  --dimensions Name=DBClusterIdentifier,Value=marketing-cluster-usw2 \
  --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average \
  --region us-west-2
```

**Acceptable lag:** < 1000ms
**If lag is high:** Wait for lag to decrease before proceeding

### 3. Backup Current Configuration

```bash
# Save current global cluster configuration
aws rds describe-global-clusters \
  --global-cluster-identifier marketing-global \
  --output json > /tmp/aurora-config-backup-$(date +%Y%m%d-%H%M%S).json

# Save current DNS configuration
aws route53 list-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --output json > /tmp/route53-config-backup-$(date +%Y%m%d-%H%M%S).json
```

### 4. Notify Team

```bash
# Send notification (example using SNS)
aws sns publish \
  --topic-arn arn:aws:sns:us-east-1:123456789012:hyundai-poc-alerts \
  --message "ALERT: Aurora failover initiated. Primary will move from us-east-1 to us-west-2. ETA: 3-5 minutes."
```

---

## Failover Procedure: US-East-1 → US-West-2

### Step 1: Remove Current Primary from Global Cluster

This step detaches the current primary (us-east-1) from the global cluster, converting it to a standalone regional cluster.

```bash
# Remove us-east-1 from global cluster
aws rds remove-from-global-cluster \
  --global-cluster-identifier marketing-global \
  --db-cluster-identifier arn:aws:rds:us-east-1:123456789012:cluster:marketing-cluster-use1 \
  --region us-east-1

# Monitor removal status
aws rds describe-db-clusters \
  --db-cluster-identifier marketing-cluster-use1 \
  --region us-east-1 \
  --query 'DBClusters[0].[Status,GlobalWriteForwardingStatus]'
```

**Expected Duration:** 30-60 seconds
**Expected Status:** "available" with GlobalWriteForwardingStatus = null

### Step 2: Promote US-West-2 to Primary Writer

This step promotes the us-west-2 secondary cluster to become the new primary writer.

```bash
# Promote us-west-2 cluster to primary
aws rds failover-global-cluster \
  --global-cluster-identifier marketing-global \
  --target-db-cluster-identifier arn:aws:rds:us-west-2:123456789012:cluster:marketing-cluster-usw2 \
  --region us-west-2

# Monitor promotion status
aws rds describe-global-clusters \
  --global-cluster-identifier marketing-global \
  --region us-west-2 \
  --query 'GlobalClusters[0].GlobalClusterMembers[?DBClusterArn==`arn:aws:rds:us-west-2:123456789012:cluster:marketing-cluster-usw2`]'
```

**Expected Duration:** 1-2 minutes
**Expected Output:** IsWriter = true for us-west-2 cluster

### Step 3: Wait for Cluster Availability

```bash
# Wait for us-west-2 cluster to be fully available
aws rds wait db-cluster-available \
  --db-cluster-identifier marketing-cluster-usw2 \
  --region us-west-2

echo "US-West-2 cluster is now available as primary"
```

**Expected Duration:** 1-2 minutes

### Step 4: Verify Write Capability

Test that the new primary can accept write operations.

```bash
# Get new primary endpoint
NEW_PRIMARY_ENDPOINT=$(aws rds describe-db-clusters \
  --db-cluster-identifier marketing-cluster-usw2 \
  --region us-west-2 \
  --query 'DBClusters[0].Endpoint' \
  --output text)

echo "New primary endpoint: $NEW_PRIMARY_ENDPOINT"

# Test write operation
mysql -h "$NEW_PRIMARY_ENDPOINT" \
  -P 3306 \
  -u admin \
  -p \
  -e "INSERT INTO hyundai_poc.health_checks (region, timestamp) VALUES ('failover-test', NOW()); SELECT LAST_INSERT_ID();"
```

**Expected Output:** Successful INSERT with new record ID

### Step 5: Verify Replication to Remaining Secondary

Confirm that the remaining secondary (Seoul) is receiving replication from the new primary.

```bash
# Get Seoul reader endpoint
SEOUL_READER_ENDPOINT=$(aws rds describe-db-clusters \
  --db-cluster-identifier marketing-cluster-apne2 \
  --region ap-northeast-2 \
  --query 'DBClusters[0].ReaderEndpoint' \
  --output text)

# Verify record replicated to Seoul
mysql -h "$SEOUL_READER_ENDPOINT" \
  -P 3306 \
  -u admin \
  -p \
  -e "SELECT * FROM hyundai_poc.health_checks WHERE region = 'failover-test' ORDER BY id DESC LIMIT 1;"
```

**Expected Output:** The test record should appear (may take 500-1000ms)

### Step 6: Update Application Configuration (If Needed)

If application is configured with hardcoded endpoints, update the configuration.

```bash
# Update environment variables in ECS task definitions (if hardcoded)
# Most applications use DNS, so this may not be necessary

# Example: Update backend task definition
aws ecs describe-task-definition \
  --task-definition hyundai-poc-backend \
  --region us-west-2 > /tmp/task-def.json

# Modify DB_WRITER_HOST in task-def.json to point to new primary endpoint
# Then register new task definition

aws ecs register-task-definition \
  --cli-input-json file:///tmp/task-def-updated.json \
  --region us-west-2

# Force new deployment with updated task definition
aws ecs update-service \
  --cluster marketing-cluster-usw2 \
  --service backend-service \
  --force-new-deployment \
  --region us-west-2
```

**Note:** If using Aurora cluster endpoints (recommended), no application changes needed.

### Step 7: Update Route53 Health Checks (Optional)

If Route53 health checks prioritize specific regions, update them to reflect the new primary.

```bash
# Create Route53 change batch for DNS updates
cat > /tmp/route53-failover-update.json <<EOF
{
  "Comment": "Update primary region priority after failover",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "db-primary.hyundai-poc.com",
        "Type": "CNAME",
        "TTL": 60,
        "ResourceRecords": [
          {
            "Value": "${NEW_PRIMARY_ENDPOINT}"
          }
        ]
      }
    }
  ]
}
EOF

# Apply DNS changes
aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --change-batch file:///tmp/route53-failover-update.json

# Monitor DNS propagation
aws route53 get-change --id <change-id>
```

**Expected Duration:** 60 seconds (based on TTL)

### Step 8: Verify Application Functionality

Test the application end-to-end to ensure it's functioning correctly.

```bash
# Test backend API health check
curl -s http://us-west-alb-dns.amazonaws.com/health | jq .

# Test database connectivity
curl -s http://us-west-alb-dns.amazonaws.com/db-health | jq .

# Test metrics endpoint
curl -s http://us-west-alb-dns.amazonaws.com/metrics | jq .

# Verify frontend dashboard
# Open browser: http://us-west-alb-dns.amazonaws.com
# Check that dashboard displays us-west-2 as current region
```

**Expected Output:** All endpoints return HTTP 200 with valid responses

### Step 9: Monitor CloudWatch Alarms

```bash
# Check for any triggered alarms
aws cloudwatch describe-alarms \
  --state-value ALARM \
  --region us-west-2

# Monitor replication lag to remaining secondary
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name AuroraGlobalDBReplicationLag \
  --dimensions Name=DBClusterIdentifier,Value=marketing-cluster-apne2 \
  --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average Maximum \
  --region ap-northeast-2
```

**Acceptable Status:** No critical alarms, replication lag < 1000ms

---

## Post-Failover Verification Checklist

- [ ] New primary (us-west-2) accepts write operations
- [ ] Replication to secondary (Seoul) is functioning
- [ ] Application endpoints return HTTP 200
- [ ] Dashboard displays correct serving region
- [ ] No critical CloudWatch alarms
- [ ] DNS records updated (if applicable)
- [ ] Team notified of successful failover
- [ ] Documentation updated with current state

---

## Rollback Procedure

If failover fails or issues are detected, roll back to original configuration.

### Rollback Step 1: Re-add US-East-1 to Global Cluster

```bash
# Re-attach us-east-1 cluster to global database
aws rds create-db-cluster \
  --global-cluster-identifier marketing-global \
  --db-cluster-identifier marketing-cluster-use1 \
  --engine aurora-mysql \
  --region us-east-1
```

### Rollback Step 2: Promote US-East-1 Back to Primary

```bash
# Promote us-east-1 back to primary writer
aws rds failover-global-cluster \
  --global-cluster-identifier marketing-global \
  --target-db-cluster-identifier arn:aws:rds:us-east-1:123456789012:cluster:marketing-cluster-use1 \
  --region us-east-1

# Wait for promotion
aws rds wait db-cluster-available \
  --db-cluster-identifier marketing-cluster-use1 \
  --region us-east-1
```

### Rollback Step 3: Verify Original State

```bash
# Verify us-east-1 is primary
aws rds describe-global-clusters \
  --global-cluster-identifier marketing-global \
  --query 'GlobalClusters[0].GlobalClusterMembers[?IsWriter==`true`].DBClusterArn'

# Expected: us-east-1 cluster ARN
```

### Rollback Step 4: Restore DNS Configuration

```bash
# Restore original Route53 configuration from backup
aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --change-batch file:///tmp/route53-config-backup-YYYYMMDD-HHMMSS.json
```

---

## Timeline & RTO

| Step | Description | Duration |
|------|-------------|----------|
| Pre-checks | Verify state, replication lag | 1-2 minutes |
| Step 1 | Remove current primary | 30-60 seconds |
| Step 2 | Promote new primary | 1-2 minutes |
| Step 3 | Wait for availability | 1-2 minutes |
| Step 4 | Verify write capability | 10-30 seconds |
| Step 5 | Verify replication | 10-30 seconds |
| Step 6 | Update application config | 0-2 minutes (optional) |
| Step 7 | Update DNS | 1 minute |
| Step 8 | Verify application | 1-2 minutes |
| **Total RTO** | | **3-5 minutes** |

**Note:** Actual RTO may vary based on replication lag and DNS propagation.

---

## Common Issues & Troubleshooting

### Issue 1: Replication Lag is High

**Symptom:** Replication lag > 5 seconds

**Solution:**
- Wait for lag to decrease before promoting
- Check network connectivity between regions
- Verify secondary cluster has sufficient capacity
- Check for long-running transactions on primary

### Issue 2: Promotion Fails

**Symptom:** `failover-global-cluster` command fails

**Solution:**
- Verify global cluster is in "available" state
- Check that target cluster is in the global database
- Ensure cluster is not in "upgrading" or "modifying" state
- Review CloudWatch logs for errors

### Issue 3: Application Cannot Connect to New Primary

**Symptom:** Connection errors after failover

**Solution:**
- Verify security groups allow traffic from application subnets
- Check that endpoint URL is correct
- Verify database credentials are valid
- Test connectivity using `telnet` or `nc`:
  ```bash
  telnet marketing-cluster-usw2.cluster-xxx.us-west-2.rds.amazonaws.com 3306
  ```

### Issue 4: DNS Not Resolving to New Region

**Symptom:** DNS still points to old primary

**Solution:**
- Wait for DNS TTL to expire (60 seconds)
- Flush local DNS cache:
  ```bash
  # macOS
  sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder

  # Linux
  sudo systemd-resolve --flush-caches
  ```
- Verify Route53 change applied:
  ```bash
  aws route53 get-change --id <change-id>
  ```

---

## Emergency Contacts

| Role | Contact | Phone |
|------|---------|-------|
| Database Administrator | [Name] | [Phone] |
| DevOps Lead | [Name] | [Phone] |
| AWS Support | AWS Console | Premium Support |

---

## Revision History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2025-10-27 | 1.0 | Hyundai POC Team | Initial runbook creation |

---

## Additional Resources

- [AWS Aurora Global Database Documentation](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-global-database.html)
- [Aurora Global Database Failover](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-global-database-disaster-recovery.html)
- [Route53 Health Checks](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-failover.html)
