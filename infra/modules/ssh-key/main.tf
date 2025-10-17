# ------------------------------------------------------------------------------
# SSH KEY MODULE - Generación y registro del key pair de EC2
# ------------------------------------------------------------------------------
# 1. Genera un par de llaves RSA (tls_private_key)
# 2. Publica la llave pública en AWS (aws_key_pair)
# 3. Guarda la llave privada en disco con permisos seguros (local_sensitive_file)
# ------------------------------------------------------------------------------

locals {
  enabled            = var.create
  private_key_target = pathexpand(var.private_key_path != null && trimspace(var.private_key_path) != "" ? var.private_key_path : "~/.ssh/${var.key_name}.pem")
}

resource "tls_private_key" "this" {
  count = local.enabled ? 1 : 0

  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "this" {
  count = local.enabled ? 1 : 0

  key_name   = var.key_name
  public_key = tls_private_key.this[0].public_key_openssh

  tags = merge(var.tags, {
    Name = var.key_name
  })
}

resource "local_sensitive_file" "private_key" {
  count = local.enabled ? 1 : 0

  content              = tls_private_key.this[0].private_key_pem
  filename             = local.private_key_target
  file_permission      = "0400"
  directory_permission = "0700"
}

# Cuando el módulo se usa únicamente para asociar una llave existente
# (create = false) exponemos igualmente una dependencia ligera para evitar
# problemas de orden de creación cuando se utilicen los outputs.
resource "null_resource" "noop" {
  count = local.enabled ? 0 : 1
}
