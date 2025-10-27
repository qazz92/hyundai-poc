# Screenshots Guide for Interview

This guide documents what screenshots to capture for the interview presentation in case of internet connectivity issues during the demo.

## Purpose

Having screenshots serves as a backup if:
- AWS Console is slow or unavailable during the interview
- Network connectivity issues prevent live demo
- You want to show "before and after" metrics
- Interview time is limited and you want to move quickly through visuals

## Required Screenshots

### 1. CloudWatch Dashboard

**What to capture:**
- Unified dashboard showing metrics from all 3 regions
- Latency measurements between regions
- Aurora replication lag gauge
- ECS task counts and health
- ALB request rates and target health

**Where to find:**
```bash
# Get dashboard URL from terraform output
cd terraform
terraform output cloudwatch_dashboard_url
```

**Screenshot filename:** `01-cloudwatch-dashboard.png`

**Key elements to ensure are visible:**
- [ ] Time range (last 1 hour or 3 hours)
- [ ] All 3 regions represented
- [ ] Latency graph with clear labels
- [ ] Replication lag metric
- [ ] ECS and ALB health indicators

**Notes for interview:**
- Point out the replication lag staying under 1 second
- Highlight latency differences (Seoul-Seoul vs Seoul-US)
- Show healthy targets in all regions

---

### 2. Frontend Dashboard

**What to capture:**
- Browser view of the Next.js application
- Current region indicator
- Latency table showing measurements to all 3 regions
- Replication lag gauge
- Health status for each region

**Where to find:**
```bash
# Access via CloudFront URL or regional ALB
terraform output cloudfront_url
# or
terraform output regional_endpoints
```

**Screenshot filename:** `02-frontend-dashboard.png`

**Key elements to ensure are visible:**
- [ ] "Hyundai Motors Global Infrastructure POC" header
- [ ] Current region clearly displayed
- [ ] Latency table with all 3 regions
- [ ] Color-coded latency (green/yellow/red)
- [ ] Replication lag metric
- [ ] All health checks showing green

**Notes for interview:**
- Demonstrate geographic routing by showing different regions
- Explain the color coding (green <100ms, yellow 100-200ms, red >200ms)
- Point out the replication lag being under 1 second

---

### 3. ECS Console - Service Health

**What to capture:**
- ECS console showing all services running
- Task counts (running vs desired)
- Service status (ACTIVE)
- One screenshot per region or combined view

**Where to find:**
- AWS Console → ECS → Clusters
- Select cluster: `hyundai-poc-cluster-seoul`, `hyundai-poc-cluster-us-east`, or `hyundai-poc-cluster-us-west`
- Services tab

**Screenshot filenames:**
- `03a-ecs-seoul-services.png`
- `03b-ecs-us-east-services.png`
- `03c-ecs-us-west-services.png`

**Key elements to ensure are visible:**
- [ ] Cluster name clearly visible
- [ ] All services showing ACTIVE status
- [ ] Running count matching desired count (e.g., 2/2)
- [ ] Task definitions and revisions
- [ ] Load balancer health (healthy targets)

**Notes for interview:**
- Explain ECS Fargate architecture (no servers to manage)
- Point out auto-replacement of failed tasks
- Mention the load balancer integration

---

### 4. Aurora Console - Global Database

**What to capture:**
- RDS console showing Aurora Global Database
- Primary cluster in us-east-1
- Secondary clusters in Seoul and US-West
- Replication lag metrics
- Cluster endpoints (writer and reader)

**Where to find:**
- AWS Console → RDS → Databases
- Filter by "hyundai-poc" or "marketing"
- Click on global database to see all regional clusters

**Screenshot filenames:**
- `04a-aurora-global-database.png`
- `04b-aurora-primary-us-east.png`
- `04c-aurora-secondary-seoul.png`
- `04d-aurora-secondary-us-west.png`

**Key elements to ensure are visible:**
- [ ] Global database identifier
- [ ] Primary region (us-east-1) clearly marked
- [ ] Secondary regions (ap-northeast-2, us-west-2)
- [ ] Cluster status (Available)
- [ ] Engine version (Aurora MySQL 8.0)
- [ ] ACU capacity (0.5-2 or current usage)
- [ ] Writer and reader endpoints

**Notes for interview:**
- Explain Aurora Serverless v2 auto-scaling
- Point out the global database replication topology
- Mention the replication lag (typically <1 second)
- Discuss failover capability

---

### 5. Route53 Console - Geolocation Routing

**What to capture:**
- Route53 hosted zone for hyundai-poc.com
- DNS records with geolocation routing policies
- Record details showing Asia → Seoul, US → US regions

**Where to find:**
- AWS Console → Route53 → Hosted zones
- Select hosted zone for hyundai-poc.com
- Show record sets with geolocation policies

**Screenshot filenames:**
- `05a-route53-hosted-zone.png`
- `05b-route53-geolocation-records.png`

**Key elements to ensure are visible:**
- [ ] Hosted zone ID
- [ ] DNS records (A or CNAME)
- [ ] Routing policy: Geolocation
- [ ] Location mappings (Asia → Seoul ALB, US East → US-East ALB, etc.)
- [ ] TTL values (60 seconds for fast failover)
- [ ] Health checks (if configured)

**Notes for interview:**
- Explain how geolocation routing directs users to nearest region
- Discuss the 60-second TTL for fast DNS updates during failover
- Mention how this reduces latency by 3-5x for local users

---

### 6. CloudFront Console - Distribution

**What to capture:**
- CloudFront distribution configuration
- Origins (all 3 regional ALBs)
- Origin failover configuration
- Distribution domain name
- Status (Deployed)

**Where to find:**
- AWS Console → CloudFront → Distributions
- Select distribution (look for hyundai-poc in comment)
- Origins tab and Origin Groups tab

**Screenshot filenames:**
- `06a-cloudfront-distribution.png`
- `06b-cloudfront-origins.png`
- `06c-cloudfront-origin-failover.png`

**Key elements to ensure are visible:**
- [ ] Distribution ID and domain name
- [ ] Status: Deployed
- [ ] All 3 origins (Seoul, US-East, US-West ALBs)
- [ ] Origin group with failover configuration
- [ ] Primary, secondary, tertiary origin order
- [ ] Cache behavior settings
- [ ] Viewer protocol policy (Redirect HTTP to HTTPS)

**Notes for interview:**
- Explain CloudFront edge locations reducing latency
- Discuss origin failover for high availability
- Mention cache behavior optimization for static assets

---

### 7. VPC Console - Network Architecture

**What to capture:**
- VPC dashboard showing all 3 regional VPCs
- Subnets (public and private)
- Route tables with NAT Gateway and Internet Gateway routes
- Security groups

**Where to find:**
- AWS Console → VPC → Your VPCs
- Filter by tag: Project = Hyundai-POC
- Switch regions to show all 3

**Screenshot filenames:**
- `07a-vpc-seoul.png`
- `07b-vpc-us-east.png`
- `07c-vpc-us-west.png`

**Key elements to ensure are visible:**
- [ ] VPC CIDR blocks (10.0.0.0/16, 10.1.0.0/16, 10.2.0.0/16)
- [ ] Public subnets (with Internet Gateway route)
- [ ] Private subnets (with NAT Gateway route)
- [ ] Availability Zones (2 AZs per region)
- [ ] NAT Gateway and Internet Gateway

**Notes for interview:**
- Explain public vs private subnet architecture
- Discuss multi-AZ design for high availability
- Mention security group least-privilege configuration

---

### 8. Application Load Balancer - Target Health

**What to capture:**
- ALB target group showing healthy targets
- Health check configuration
- Target details (IP addresses, ports, status)

**Where to find:**
- AWS Console → EC2 → Load Balancers → Target Groups
- Select target group for hyundai-poc
- Targets tab

**Screenshot filenames:**
- `08a-alb-target-health-seoul.png`
- `08b-alb-target-health-us-east.png`
- `08c-alb-target-health-us-west.png`

**Key elements to ensure are visible:**
- [ ] Target group name
- [ ] Health status: Healthy
- [ ] Number of healthy targets (e.g., 2/2)
- [ ] Target IP addresses
- [ ] Health check configuration (path, interval, timeout)
- [ ] Port numbers (3000 for frontend, 3001 for backend)

**Notes for interview:**
- Explain ALB health check mechanism
- Discuss automatic target registration/deregistration
- Mention cross-zone load balancing

---

### 9. Billing Dashboard - Cost Verification

**What to capture:**
- AWS Billing console showing daily cost breakdown
- Cost by service (Aurora, ECS, NAT Gateway, ALB)
- Total cost for 24-hour period
- Tag-based cost allocation (Project: Hyundai-POC)

**Where to find:**
- AWS Console → Billing → Cost Explorer
- Filter by time range: Last 24 hours or Last 7 days
- Group by: Service or Tag (Project)

**Screenshot filename:** `09-billing-dashboard.png`

**Key elements to ensure are visible:**
- [ ] Time range clearly shown
- [ ] Total cost for POC (<$50 for 24 hours)
- [ ] Cost breakdown by service
- [ ] Cost by region (if available)
- [ ] Trend showing cost will go to $0 after teardown

**Notes for interview:**
- Demonstrate cost awareness and optimization
- Show actual cost vs estimated cost
- Discuss cost breakdown by component
- Mention teardown strategy to avoid ongoing charges

---

### 10. Terraform Output - Infrastructure Details

**What to capture:**
- Terminal screenshot showing `terraform output`
- ALB URLs for all regions
- Aurora endpoints (writer and reader)
- CloudFront domain
- Route53 hosted zone ID

**Where to find:**
```bash
cd terraform
terraform output
# or
terraform output -json | jq
```

**Screenshot filename:** `10-terraform-outputs.png`

**Key elements to ensure are visible:**
- [ ] Regional ALB DNS names
- [ ] Aurora writer endpoint (us-east-1)
- [ ] Aurora reader endpoints (all regions)
- [ ] CloudFront distribution domain
- [ ] Route53 hosted zone ID
- [ ] Any custom outputs (e.g., VPC IDs, security group IDs)

**Notes for interview:**
- Demonstrate Infrastructure-as-Code approach
- Show how outputs are used for verification and testing
- Mention Terraform state management

---

## Screenshot Capture Checklist

Before the interview, capture all screenshots:

- [ ] 01-cloudwatch-dashboard.png
- [ ] 02-frontend-dashboard.png
- [ ] 03a-ecs-seoul-services.png
- [ ] 03b-ecs-us-east-services.png
- [ ] 03c-ecs-us-west-services.png
- [ ] 04a-aurora-global-database.png
- [ ] 04b-aurora-primary-us-east.png
- [ ] 04c-aurora-secondary-seoul.png
- [ ] 04d-aurora-secondary-us-west.png
- [ ] 05a-route53-hosted-zone.png
- [ ] 05b-route53-geolocation-records.png
- [ ] 06a-cloudfront-distribution.png
- [ ] 06b-cloudfront-origins.png
- [ ] 06c-cloudfront-origin-failover.png
- [ ] 07a-vpc-seoul.png
- [ ] 07b-vpc-us-east.png
- [ ] 07c-vpc-us-west.png
- [ ] 08a-alb-target-health-seoul.png
- [ ] 08b-alb-target-health-us-east.png
- [ ] 08c-alb-target-health-us-west.png
- [ ] 09-billing-dashboard.png
- [ ] 10-terraform-outputs.png

## Screenshot Tips

1. **Resolution**: Use full-screen browser window at 1920x1080 or higher
2. **Zoom**: 100% zoom level for clarity
3. **Annotations**: Consider adding arrows or highlights to key metrics
4. **File Format**: PNG for lossless quality
5. **File Size**: Compress if needed (use TinyPNG or similar)
6. **Organization**: Name files consistently with prefixes for easy sorting
7. **Backup**: Keep screenshots in Google Drive or cloud storage

## Interview Presentation Flow

Use screenshots in this order:

1. **Architecture Overview** (Mermaid diagram in README)
2. **Live Frontend Dashboard** (02-frontend-dashboard.png as backup)
3. **CloudWatch Metrics** (01-cloudwatch-dashboard.png)
4. **Infrastructure Details** (03-10 screenshots as needed)
5. **Cost Breakdown** (09-billing-dashboard.png)
6. **Failover Runbook** (docs/failover-runbook.md)

## Post-Interview

After the interview, you can use these screenshots for:
- Portfolio documentation
- LinkedIn posts showcasing the project
- GitHub README visual enhancements
- Blog posts or articles about multi-region architecture
- Reference for future similar projects

---

## Additional Visual Assets

Consider creating these additional visuals if time permits:

### Architecture Diagram (Visual)

Use draw.io or Lucidchart to create a polished version of the Mermaid diagram:
- Include AWS service icons
- Show data flow with arrows
- Highlight replication and failover paths
- Export as high-resolution PNG

### Latency Comparison Chart

Create a bar chart showing:
- Korea to Korea: ~30ms
- Korea to US-East: ~180ms
- Korea to US-West: ~120ms
- Demonstrates 3-5x latency improvement with geographic routing

### Cost Breakdown Pie Chart

Visualize cost distribution:
- Aurora: 40%
- ECS Fargate: 22%
- NAT Gateway: 20%
- ALB: 12%
- Other: 6%

---

Save all screenshots to this directory: `/docs/screenshots/`
