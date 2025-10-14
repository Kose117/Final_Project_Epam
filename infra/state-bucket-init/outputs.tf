output "backend_config_instructions" {
  value = <<-EOT
    
    ╔════════════════════════════════════════════════════════════════════════╗
    ║  ✅ BUCKET CREADO EXITOSAMENTE                                         ║
    ╚════════════════════════════════════════════════════════════════════════╝
    
    Copia esta configuración a backend-config/backend.hcl:
    
    bucket               = "${aws_s3_bucket.tf_state.bucket}"
    key                  = "root/terraform.tfstate"
    region               = "${aws_s3_bucket.tf_state.region}"
    use_lockfile         = true
    workspace_key_prefix = "env"
    
    Luego inicializa tu proyecto con:
    
    cd env/qa  # o env/prod
    terraform init -backend-config=../../backend-config/backend.hcl
    terraform workspace new qa  # o prod
    terraform apply
  EOT
  description = "Instrucciones para configurar el backend remoto"
}