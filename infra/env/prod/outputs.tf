output "alb_dns_name" {
  value       = module.alb.alb_dns_name
  description = "URL del Application Load Balancer"
}

output "bastion_ip" {
  value       = module.bastion.public_ip
  description = "IP pública del Bastion Host"
}

output "rds_endpoint" {
  value       = module.rds.endpoint
  description = "Endpoint de la base de datos RDS"
  sensitive   = true
}

output "frontend_private_ip" {
  value       = module.frontend.private_ip
  description = "IP privada del servidor frontend"
}

output "backend_private_ip" {
  value       = module.backend.private_ip
  description = "IP privada del servidor backend"
}

output "cloudwatch_dashboard" {
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${module.monitoring.dashboard_name}"
  description = "URL del dashboard de CloudWatch"
}

# Output para inventario de Ansible
output "ansible_connection_info" {
  value = {
    bastion_host    = module.bastion.public_ip
    frontend_host   = module.frontend.private_ip
    backend_host    = module.backend.private_ip
    db_host         = module.rds.endpoint
    ssh_user        = "ec2-user"
    ssh_key_path    = "~/.ssh/${var.ssh_key_name}.pem"
  }
  description = "Información de conexión para Ansible"
}