output "instance_ids" {
  description = "Lista de IDs de instancias backend"
  value       = aws_instance.be[*].id
}

output "private_ips" {
  description = "Lista de IPs privadas de las instancias backend"
  value       = aws_instance.be[*].private_ip
}

output "sg_id" {
  value       = aws_security_group.app.id
  description = "Security group que permite tráfico al backend"
}
