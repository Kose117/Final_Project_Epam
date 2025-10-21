# ------------------------------------------------------------------------------
# S3 BUCKET - Almacenamiento del Terraform State
# ------------------------------------------------------------------------------
# Crea el bucket principal donde se guardaran todos los archivos .tfstate
# El versionamiento permite recuperar estados anteriores en caso de error.
# ------------------------------------------------------------------------------
resource "aws_s3_bucket" "tf_state" {
  bucket        = var.bucket_name
  force_destroy = true // Permitir destruir el bucket aunque contenga objetos

  lifecycle {
    prevent_destroy = false // Evita que terraform destroy elimine el bucket por accidente
  }

  tags = merge(var.tags, { Name = var.bucket_name })
}

locals {
  bucket_arn         = "arn:aws:s3:::${var.bucket_name}"
  bucket_objects_arn = "arn:aws:s3:::${var.bucket_name}/*"
}

# ------------------------------------------------------------------------------
# OWNERSHIP CONTROLS - Control de propiedad de objetos
# ------------------------------------------------------------------------------
# Fuerza que el dueno del bucket sea tambien el dueno de todos los objetos.
# Esto simplifica la gestion de permisos y previene problemas con ACLs.
# ------------------------------------------------------------------------------
resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    object_ownership = "BucketOwnerEnforced" // El bucket owner posee todos los objetos
  }
}

# ------------------------------------------------------------------------------
# PUBLIC ACCESS BLOCK - Bloqueo de acceso publico
# ------------------------------------------------------------------------------
# Asegura que el bucket NUNCA sea accesible publicamente.
# CRITICO: El state contiene informacion sensible (IPs, IDs, credenciales).
# ------------------------------------------------------------------------------
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true // Bloquea nuevas ACLs publicas
  block_public_policy     = true // Bloquea nuevas politicas publicas
  ignore_public_acls      = true // Ignora ACLs publicas existentes
  restrict_public_buckets = true // Restringe acceso publico
}

# ------------------------------------------------------------------------------
# VERSIONING - Historial de objetos del tfstate
# ------------------------------------------------------------------------------
# Activa versionamiento para poder recuperar estados anteriores ante un error.
# ------------------------------------------------------------------------------
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ------------------------------------------------------------------------------
# DEFAULT ENCRYPTION - Encriptado en reposo obligatorio
# ------------------------------------------------------------------------------
# Garantiza que todo objeto se guarde con SSE-S3 (AES256) para proteger el state.
# ------------------------------------------------------------------------------
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
data "aws_iam_policy_document" "deny_insecure_transport" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.tf_state.arn,
      "${aws_s3_bucket.tf_state.arn}/*",
    ]

    principals {
      // Aplica a cualquier principal
      type        = "*"
      identifiers = ["*"]
    }

    // Condicion: niega solo si NO es HTTPS
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}


# ------------------------------------------------------------------------------
# BUCKET POLICY - Aplicacion de la politica de seguridad
# ------------------------------------------------------------------------------
# Adjunta la politica IAM al bucket para hacerla efectiva.
# Despues de esto, cualquier intento de acceso sin HTTPS sera rechazado.
# ------------------------------------------------------------------------------
resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.tf_state.id
  policy = data.aws_iam_policy_document.deny_insecure_transport.json
}

# ------------------------------------------------------------------------------
# IAM POLICY - Permisos minimos para gestionar el bucket del tfstate
# ------------------------------------------------------------------------------
# Algunos equipos utilizan usuarios IAM sin privilegios de administrador. Para
# facilitar la creacion del bucket, se puede adjuntar automaticamente una
# politica con los permisos minimos requeridos (crear el bucket, aplicar
# versionamiento, encriptacion, politicas y gestionar objetos del state).
# ------------------------------------------------------------------------------

