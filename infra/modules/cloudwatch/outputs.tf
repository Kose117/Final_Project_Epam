output "dashboard_name" {
  value       = aws_cloudwatch_dashboard.main.dashboard_name
  description = "Nombre del dashboard de CloudWatch"
}