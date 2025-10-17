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

output "iam_policy_instructions" {
  value = <<-EOT
    %{ if local.attach_iam_policies }
    ╔════════════════════════════════════════════════════════════════════════╗
    ║  ✅ POLÍTICA IAM PARA EL STATE                                         ║
    ╚════════════════════════════════════════════════════════════════════════╝

    Política creada: ${try(aws_iam_policy.state_bucket_access[0].arn, "(error obteniendo ARN)")}
    Usuarios con acceso: ${join(", ", var.iam_usernames)}

    Cada usuario ya puede ejecutar "terraform init" y "terraform apply" sobre el
    bucket ${aws_s3_bucket.tf_state.bucket}. Si necesitas adjuntarlo a otro usuario
    en el futuro, añade su nombre en "iam_usernames" y vuelve a aplicar.
    %{ else }
    ╔════════════════════════════════════════════════════════════════════════╗
    ║  ℹ️  SIN POLÍTICA IAM OPCIONAL                                         ║
    ╚════════════════════════════════════════════════════════════════════════╝

    Ejecutaste el módulo sin especificar "iam_usernames". Si tu usuario IAM no
    tiene privilegios suficientes para crear el bucket, vuelve a aplicar
    incluyendo: -var='iam_usernames=["tu-usuario"]'
    %{ endif }
  EOT

  description = "Detalle de la política IAM opcional para administrar el bucket"
}
