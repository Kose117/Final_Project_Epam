# ==============================================================================
# CLOUDWATCH MODULE - Monitoreo y alarmas
# ==============================================================================
# Dashboard y alarmas para monitorear CPU, latencia y errores de la infra.
# Solución in-house sin costos adicionales (requisito del cliente).
# ==============================================================================

# ------------------------------------------------------------------------------
# DASHBOARD - Panel de métricas
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.name_prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", { stat = "Average", label = "Frontend CPU" }],
            ["...", { stat = "Average", label = "Backend CPU" }],
            ["AWS/RDS", "CPUUtilization", { stat = "Average", label = "RDS CPU" }]
          ]
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
            ["AWS/ApplicationELB", "TargetResponseTime", { stat = "Average" }],
            [".", "RequestCount", { stat = "Sum" }]
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
  evaluation_periods  = 2  // 2 períodos consecutivos
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
  alarm_name          = "${var.name_prefix}-backend-high-cpu"
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
    InstanceId = var.backend_instance
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
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.name_prefix}-alb-high-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10  // Más de 10 errores 5xx en 5 minutos
  alarm_description   = "ALB returning too many 5xx errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
}