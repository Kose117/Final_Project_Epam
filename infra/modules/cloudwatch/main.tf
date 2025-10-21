# ==============================================================================
# CLOUDWATCH MODULE - Monitoreo y alarmas
# ==============================================================================
# Dashboard y alarmas para monitorear CPU, latencia y errores de la infra.
# ==============================================================================

locals {
  backend_cpu_metrics = [
    for id in var.backend_instances :
    [
      "AWS/EC2",
      "CPUUtilization",
      "InstanceId",
      id,
      {
        "stat"  = "Average",
        "label" = "Backend ${replace(id, "i-", "")}" 
      }
    ]
  ]
}

# ------------------------------------------------------------------------------
# DASHBOARD - Panel de metricas
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.name_prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = concat(
            [
              [
                "AWS/EC2",
                "CPUUtilization",
                "InstanceId",
                var.frontend_instance,
                { "stat" = "Average", "label" = "Frontend" }
              ]
            ],
            local.backend_cpu_metrics,
            [
              [
                "AWS/RDS",
                "CPUUtilization",
                "DBInstanceIdentifier",
                var.rds_instance,
                { "stat" = "Average", "label" = "RDS" }
              ]
            ]
          )
          period = 300  // 5 minutos
          region = var.region
          title  = "CPU Utilization"
          yAxis  = { left = { min = 0, max = 100 } }
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            [
              "AWS/ApplicationELB",
              "TargetResponseTime",
              "TargetGroup",
              var.tg_frontend_arn_suffix,
              "LoadBalancer",
              var.public_alb_arn_suffix,
              { stat = "Average", label = "Frontend TG - Latencia" }
            ],
            [
              "AWS/ApplicationELB",
              "TargetResponseTime",
              "TargetGroup",
              var.tg_backend_arn_suffix,
              "LoadBalancer",
              var.internal_alb_arn_suffix,
              { stat = "Average", label = "Backend TG - Latencia" }
            ],
            [
              "AWS/ApplicationELB",
              "RequestCount",
              "TargetGroup",
              var.tg_frontend_arn_suffix,
              "LoadBalancer",
              var.public_alb_arn_suffix,
              { stat = "Sum", label = "Frontend TG - Requests" }
            ],
            [
              "AWS/ApplicationELB",
              "RequestCount",
              "TargetGroup",
              var.tg_backend_arn_suffix,
              "LoadBalancer",
              var.internal_alb_arn_suffix,
              { stat = "Sum", label = "Backend TG - Requests" }
            ]
          ]
          period = 300
          region = var.region
          title  = "ALB Performance"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/RDS", "DatabaseConnections", { stat = "Average" }],
            [".", "FreeableMemory", { stat = "Average" }]
          ]
          period = 300
          region = var.region
          title  = "RDS Health"
        }
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# ALARM - CPU alto en Frontend
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "frontend_cpu" {
  alarm_name          = "${var.name_prefix}-frontend-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2  // 2 periodos consecutivos
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Frontend CPU > 80%"
  treat_missing_data  = "notBreaching"  // No alarmar si no hay datos

  dimensions = {
    InstanceId = var.frontend_instance
  }
}

# ------------------------------------------------------------------------------
# ALARM - CPU alto en Backend
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "backend_cpu" {
  for_each            = { for idx, id in var.backend_instances : tostring(idx) => id }
  alarm_name          = format("%s-be-%s-high-cpu", var.name_prefix, each.key)
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Backend CPU > 80%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = each.value
  }
}

# ------------------------------------------------------------------------------
# ALARM - CPU alto en RDS
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${var.name_prefix}-rds-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS CPU > 80%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = var.rds_instance
  }
}

# ------------------------------------------------------------------------------
# ALARM - ALB con muchos errores 5xx
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "alb_public_5xx" {
  alarm_name          = "${var.name_prefix}-public-alb-high-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10  // Mas de 10 errores 5xx en 5 minutos
  alarm_description   = "Public ALB returning too many 5xx errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.public_alb_arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_internal_5xx" {
  alarm_name          = "${var.name_prefix}-internal-alb-high-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Internal ALB returning too many 5xx errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.internal_alb_arn_suffix
  }
}
