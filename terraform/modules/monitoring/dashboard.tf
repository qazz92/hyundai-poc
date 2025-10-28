# CloudWatch Dashboard with Proper Dimensions
# Separates Frontend and Backend Metrics

resource "aws_cloudwatch_dashboard" "main_new" {
  dashboard_name = "Hyundai-POC-Global-v2"

  dashboard_body = jsonencode({
    widgets = [
      # ====================
      # Row 1: Frontend Healthy Hosts (US-East only)
      # ====================
      {
        type   = "metric"
        width  = 8
        height = 6
        x      = 8
        y      = 0
        properties = {
          title  = "US-East - Frontend Healthy Hosts"
          region = "us-east-1"
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", var.us_east_frontend_tg_arn_suffix, "LoadBalancer", var.us_east_alb_arn_suffix, { stat = "Average", label = "Frontend" }]
          ]
          period = 60
          stat   = "Average"
          yAxis = {
            left = { min = 0 }
          }
        }
      },

      # ====================
      # Row 2: Backend Healthy Hosts (Seoul, US-East, US-West)
      # ====================
      {
        type   = "metric"
        width  = 8
        height = 6
        x      = 0
        y      = 6
        properties = {
          title  = "Seoul - Backend Healthy Hosts"
          region = "ap-northeast-2"
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", var.seoul_backend_tg_arn_suffix, "LoadBalancer", var.seoul_alb_arn_suffix, { stat = "Average", label = "Backend" }]
          ]
          period = 60
          stat   = "Average"
          yAxis = {
            left = { min = 0 }
          }
        }
      },
      {
        type   = "metric"
        width  = 8
        height = 6
        x      = 8
        y      = 6
        properties = {
          title  = "US-East - Backend Healthy Hosts"
          region = "us-east-1"
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", var.us_east_backend_tg_arn_suffix, "LoadBalancer", var.us_east_alb_arn_suffix, { stat = "Average", label = "Backend" }]
          ]
          period = 60
          stat   = "Average"
          yAxis = {
            left = { min = 0 }
          }
        }
      },
      {
        type   = "metric"
        width  = 8
        height = 6
        x      = 16
        y      = 6
        properties = {
          title  = "US-West - Backend Healthy Hosts"
          region = "us-west-2"
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", var.us_west_backend_tg_arn_suffix, "LoadBalancer", var.us_west_alb_arn_suffix, { stat = "Average", label = "Backend" }]
          ]
          period = 60
          stat   = "Average"
          yAxis = {
            left = { min = 0 }
          }
        }
      },

      # ====================
      # Row 3: Frontend CPU Utilization (US-East only)
      # ====================
      {
        type   = "metric"
        width  = 8
        height = 6
        x      = 8
        y      = 12
        properties = {
          title  = "US-East - Frontend CPU"
          region = "us-east-1"
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.us_east_ecs_cluster_name, "ServiceName", var.us_east_frontend_service_name, { stat = "Average" }]
          ]
          period = 60
          stat   = "Average"
          yAxis = {
            left = { min = 0, max = 100 }
          }
        }
      },

      # ====================
      # Row 4: Backend CPU Utilization (Seoul, US-East, US-West)
      # ====================
      {
        type   = "metric"
        width  = 8
        height = 6
        x      = 0
        y      = 18
        properties = {
          title  = "Seoul - Backend CPU"
          region = "ap-northeast-2"
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.seoul_ecs_cluster_name, "ServiceName", var.seoul_backend_service_name, { stat = "Average" }]
          ]
          period = 60
          stat   = "Average"
          yAxis = {
            left = { min = 0, max = 100 }
          }
        }
      },
      {
        type   = "metric"
        width  = 8
        height = 6
        x      = 8
        y      = 18
        properties = {
          title  = "US-East - Backend CPU"
          region = "us-east-1"
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.us_east_ecs_cluster_name, "ServiceName", var.us_east_backend_service_name, { stat = "Average" }]
          ]
          period = 60
          stat   = "Average"
          yAxis = {
            left = { min = 0, max = 100 }
          }
        }
      },
      {
        type   = "metric"
        width  = 8
        height = 6
        x      = 16
        y      = 18
        properties = {
          title  = "US-West - Backend CPU"
          region = "us-west-2"
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.us_west_ecs_cluster_name, "ServiceName", var.us_west_backend_service_name, { stat = "Average" }]
          ]
          period = 60
          stat   = "Average"
          yAxis = {
            left = { min = 0, max = 100 }
          }
        }
      },

      # ====================
      # Row 5: Frontend Memory Utilization (US-East only)
      # ====================
      {
        type   = "metric"
        width  = 8
        height = 6
        x      = 8
        y      = 24
        properties = {
          title  = "US-East - Frontend Memory"
          region = "us-east-1"
          metrics = [
            ["AWS/ECS", "MemoryUtilization", "ClusterName", var.us_east_ecs_cluster_name, "ServiceName", var.us_east_frontend_service_name, { stat = "Average" }]
          ]
          period = 60
          stat   = "Average"
          yAxis = {
            left = { min = 0, max = 100 }
          }
        }
      },

      # ====================
      # Row 6: Backend Memory Utilization (Seoul, US-East, US-West)
      # ====================
      {
        type   = "metric"
        width  = 8
        height = 6
        x      = 0
        y      = 30
        properties = {
          title  = "Seoul - Backend Memory"
          region = "ap-northeast-2"
          metrics = [
            ["AWS/ECS", "MemoryUtilization", "ClusterName", var.seoul_ecs_cluster_name, "ServiceName", var.seoul_backend_service_name, { stat = "Average" }]
          ]
          period = 60
          stat   = "Average"
          yAxis = {
            left = { min = 0, max = 100 }
          }
        }
      },
      {
        type   = "metric"
        width  = 8
        height = 6
        x      = 8
        y      = 30
        properties = {
          title  = "US-East - Backend Memory"
          region = "us-east-1"
          metrics = [
            ["AWS/ECS", "MemoryUtilization", "ClusterName", var.us_east_ecs_cluster_name, "ServiceName", var.us_east_backend_service_name, { stat = "Average" }]
          ]
          period = 60
          stat   = "Average"
          yAxis = {
            left = { min = 0, max = 100 }
          }
        }
      },
      {
        type   = "metric"
        width  = 8
        height = 6
        x      = 16
        y      = 30
        properties = {
          title  = "US-West - Backend Memory"
          region = "us-west-2"
          metrics = [
            ["AWS/ECS", "MemoryUtilization", "ClusterName", var.us_west_ecs_cluster_name, "ServiceName", var.us_west_backend_service_name, { stat = "Average" }]
          ]
          period = 60
          stat   = "Average"
          yAxis = {
            left = { min = 0, max = 100 }
          }
        }
      },

      # ====================
      # Row 7: ALB Request Count and Response Time
      # ====================
      {
        type   = "metric"
        width  = 12
        height = 6
        x      = 0
        y      = 36
        properties = {
          title   = "ALB Request Count - All Regions"
          region  = "us-east-1"
          view    = "timeSeries"
          stacked = true
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.seoul_alb_arn_suffix, { region = "ap-northeast-2", stat = "Sum", label = "Seoul" }],
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.us_east_alb_arn_suffix, { region = "us-east-1", stat = "Sum", label = "US-East" }],
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.us_west_alb_arn_suffix, { region = "us-west-2", stat = "Sum", label = "US-West" }]
          ]
          period = 60
          stat   = "Sum"
          yAxis = {
            left = { min = 0 }
          }
        }
      },
      {
        type   = "metric"
        width  = 12
        height = 6
        x      = 12
        y      = 36
        properties = {
          title  = "ALB Target Response Time - All Regions"
          region = "us-east-1"
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.seoul_alb_arn_suffix, { region = "ap-northeast-2", stat = "Average", label = "Seoul" }],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.us_east_alb_arn_suffix, { region = "us-east-1", stat = "Average", label = "US-East" }],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.us_west_alb_arn_suffix, { region = "us-west-2", stat = "Average", label = "US-West" }]
          ]
          period = 60
          stat   = "Average"
          yAxis = {
            left = { min = 0 }
          }
        }
      },

      # ====================
      # Row 8: Aurora Database Metrics
      # ====================
      {
        type   = "metric"
        width  = 8
        height = 6
        x      = 0
        y      = 42
        properties = {
          title  = "Aurora CPU Utilization - All Clusters"
          region = "us-east-1"
          metrics = [
            ["AWS/RDS", "CPUUtilization", { region = "us-east-1", stat = "Average", label = "Primary (US-East)" }],
            ["AWS/RDS", "CPUUtilization", { region = "ap-northeast-2", stat = "Average", label = "Seoul" }],
            ["AWS/RDS", "CPUUtilization", { region = "us-west-2", stat = "Average", label = "US-West" }]
          ]
          period = 60
          stat   = "Average"
          yAxis = {
            left = { min = 0, max = 100 }
          }
        }
      },
      {
        type   = "metric"
        width  = 8
        height = 6
        x      = 8
        y      = 42
        properties = {
          title  = "Aurora Database Connections - All Clusters"
          region = "us-east-1"
          metrics = [
            ["AWS/RDS", "DatabaseConnections", { region = "us-east-1", stat = "Average", label = "Primary (US-East)" }],
            ["AWS/RDS", "DatabaseConnections", { region = "ap-northeast-2", stat = "Average", label = "Seoul" }],
            ["AWS/RDS", "DatabaseConnections", { region = "us-west-2", stat = "Average", label = "US-West" }]
          ]
          period = 60
          stat   = "Average"
          yAxis = {
            left = { min = 0 }
          }
        }
      },
      {
        type   = "metric"
        width  = 8
        height = 6
        x      = 16
        y      = 42
        properties = {
          title  = "Aurora Replication Lag (Secondaries)"
          region = "us-east-1"
          metrics = [
            ["AWS/RDS", "AuroraGlobalDBReplicationLag", "DBClusterIdentifier", "hyundai-poc-cluster-seoul", { region = "ap-northeast-2", stat = "Average", label = "Seoul" }],
            [".", ".", ".", "hyundai-poc-cluster-us-west", { region = "us-west-2", stat = "Average", label = "US-West" }]
          ]
          period = 60
          stat   = "Average"
          yAxis = {
            left = { min = 0 }
          }
        }
      }
    ]
  })
}
