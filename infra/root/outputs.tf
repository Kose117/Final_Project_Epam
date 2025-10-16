# ==============================================================================
# OUTPUTS - Root Module
# ==============================================================================
# Información importante que se muestra después de terraform apply
# ==============================================================================

# ------------------------------------------------------------------------------
# URLs y Endpoints Públicos
# ------------------------------------------------------------------------------
output "alb_dns_name" {
  value       = module.alb.alb_dns_name
  description = "URL del Application Load Balancer"
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

output "backend_private_ip" {
  value       = module.backend.private_ip
  description = "IP privada del servidor backend"
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
    backend_host  = module.backend.private_ip
    db_host       = module.rds.endpoint
    alb_dns       = module.alb.alb_dns_name
    ssh_user      = "ec2-user"
    ssh_key_path  = "~/.ssh/${var.ssh_key_name}.pem"
    
    # Comandos SSH útiles
    ssh_to_bastion  = "ssh -i ~/.ssh/${var.ssh_key_name}.pem ec2-user@${module.bastion.public_ip}"
    ssh_to_frontend = "ssh -J ec2-user@${module.bastion.public_ip} ec2-user@${module.frontend.private_ip}"
    ssh_to_backend  = "ssh -J ec2-user@${module.bastion.public_ip} ec2-user@${module.backend.private_ip}"
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
  
  🌐 Aplicación:    http://${module.alb.alb_dns_name}
  🖥️  Bastion SSH:   ssh -i ~/.ssh/${var.ssh_key_name}.pem ec2-user@${module.bastion.public_ip}
  💾 Base de Datos: ${module.rds.endpoint}
  📊 Monitoreo:     AWS Console → CloudWatch → Dashboards
  
  🔧 SIGUIENTE PASOS:
  
  1️⃣  Conectarse al Bastion:
      ssh -i ~/.ssh/${var.ssh_key_name}.pem ec2-user@${module.bastion.public_ip}
  
  2️⃣  Configurar Ansible en el Bastion (ver documentación)
  
  3️⃣  Crear inventario de Ansible con estas IPs:
      Frontend: ${module.frontend.private_ip}
      Backend:  ${module.backend.private_ip}
      RDS:      ${module.rds.endpoint}
  
  4️⃣  Ejecutar playbooks de deployment
  
  5️⃣  Verificar aplicación:
      curl http://${module.alb.alb_dns_name}/
      curl http://${module.alb.alb_dns_name}/api/health
  
  EOT
  description = "Instrucciones para los siguientes pasos"
}