output "backend_config_instructions" {
  value       = <<-EOT
    Copia esta configuracion a backend-config/backend.hcl:

    bucket               = "${aws_s3_bucket.tf_state.bucket}"
    key                  = "root/terraform.tfstate"
    region               = "${aws_s3_bucket.tf_state.region}"
    use_lockfile         = true
    workspace_key_prefix = "env"

    Caracteristicas habilitadas automaticamente:
      - Versioning para recuperar estados previos
      - Encriptado SSE-S3 (AES256)
      - Bloqueo completo de acceso publico
      - Proteccion contra terraform destroy accidental

    Luego inicializa tu proyecto con:

    cd env/qa  # o env/prod
    terraform init -backend-config=../../backend-config/backend.hcl
  EOT
  description = "Instrucciones para configurar el backend remoto"
}

