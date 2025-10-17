output "key_name" {
  description = "Nombre del key pair que deben usar otros módulos"
  value       = try(aws_key_pair.this[0].key_name, var.key_name)
}

output "private_key_path" {
  description = "Ruta absoluta donde quedó la llave privada"
  value       = try(local_sensitive_file.private_key[0].filename, local.private_key_target)
}

output "public_key_openssh" {
  description = "Llave pública en formato OpenSSH"
  value       = try(tls_private_key.this[0].public_key_openssh, null)
  sensitive   = true
}

output "private_key_pem" {
  description = "Llave privada en formato PEM"
  value       = try(tls_private_key.this[0].private_key_pem, null)
  sensitive   = true
}
