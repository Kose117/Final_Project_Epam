# ==============================================================================
# OUTPUTS - Root Module
# ==============================================================================
# Información importante que se muestra después de terraform apply
# ==============================================================================

# ------------------------------------------------------------------------------
# URLs y Endpoints Públicos
# ------------------------------------------------------------------------------
output "alb_dns_name" {
  value       = module.alb_public.alb_dns_name
  description = "URL del Application Load Balancer público"
}

output "internal_alb_dns_name" {
  value       = module.alb_internal.alb_dns_name
  description = "DNS interno del ALB que expone el backend"
}

output "bastion_ip" {
  value       = module.bastion.public_ip
  description = "IP pública del Bastion Host para SSH"
}

output "cloudwatch_dashboard" {
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${module.monitoring.dashboard_name}"
  description = "URL del dashboard de CloudWatch"
}

# ------------------------------------------------------------------------------
# IPs Privadas (para Ansible)
# ------------------------------------------------------------------------------
output "frontend_private_ip" {
  value       = module.frontend.private_ip
  description = "IP privada del servidor frontend"
}

output "backend_private_ips" {
  value       = module.backend.private_ips
  description = "IPs privadas de los servidores backend"
}

# ------------------------------------------------------------------------------
# Base de Datos
# ------------------------------------------------------------------------------
output "rds_endpoint" {
  value       = module.rds.endpoint
  description = "Endpoint de conexión a RDS MySQL"
  sensitive   = true
}

# ------------------------------------------------------------------------------
# Información para Ansible (Human Readable)
# ------------------------------------------------------------------------------
output "ansible_connection_info" {
  value = {
    bastion_host  = module.bastion.public_ip
    frontend_host = module.frontend.private_ip
    backend_hosts = module.backend.private_ips
    db_host       = module.rds.endpoint
    public_alb_dns  = module.alb_public.alb_dns_name
    internal_alb_dns = module.alb_internal.alb_dns_name
    ssh_user      = "ec2-user"
    ssh_key_path  = "~/.ssh/${var.ssh_key_name}.pem"
    
    # Comandos SSH útiles
    ssh_to_bastion  = "ssh -i ~/.ssh/${var.ssh_key_name}.pem ec2-user@${module.bastion.public_ip}"
    ssh_to_frontend = "ssh -J ec2-user@${module.bastion.public_ip} ec2-user@${module.frontend.private_ip}"
    ssh_to_backend  = [
      for ip in module.backend.private_ips :
      "ssh -J ec2-user@${module.bastion.public_ip} ec2-user@${ip}"
    ]
  }
  description = "Información de conexión para Ansible y SSH"
}

# ------------------------------------------------------------------------------
# Instrucciones Post-Deploy
# ------------------------------------------------------------------------------
output "next_steps" {
  value = <<-EOT
  
  ╔════════════════════════════════════════════════════════════════════════╗
  ║  ✅ INFRAESTRUCTURA DESPLEGADA EXITOSAMENTE - ${upper(var.environment)}
  ╚════════════════════════════════════════════════════════════════════════╝
  
  📋 INFORMACIÓN CLAVE:
  
  🌐 Frontend:      http://${module.alb_public.alb_dns_name}
  🖥️  Bastion SSH:   ssh -i ~/.ssh/${var.ssh_key_name}.pem ec2-user@${module.bastion.public_ip}
  💾 Base de Datos: ${module.rds.endpoint}
  📊 Monitoreo:     AWS Console → CloudWatch → Dashboards
  
  🔧 SIGUIENTE PASOS:
  
  1️⃣  Conectarse al Bastion:
      ssh -i ~/.ssh/${var.ssh_key_name}.pem ec2-user@${module.bastion.public_ip}
  
  2️⃣  Configurar Ansible en el Bastion (ver documentación)
  
  3️⃣  Crear inventario de Ansible con estas IPs:
      Frontend: ${module.frontend.private_ip}
      Backend:  ${join(", ", module.backend.private_ips)}
      RDS:      ${module.rds.endpoint}
  
  4️⃣  Ejecutar playbooks de deployment
  
  5️⃣  Verificar aplicación:
      curl http://${module.alb_public.alb_dns_name}/
      # Las rutas /api/* ahora están disponibles solo dentro de la VPC vía ${module.alb_internal.alb_dns_name}
  
  EOT
  description = "Instrucciones para los siguientes pasos"
}