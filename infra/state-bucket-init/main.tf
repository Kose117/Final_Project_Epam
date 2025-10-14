# ==============================================================================
# TERRAFORM STATE BUCKET - Inicialización
# ==============================================================================
# Este archivo crea la infraestructura necesaria para almacenar el state remoto
# de Terraform de forma segura en AWS S3.
#
# COMPONENTES:
# - Bucket S3 con versionamiento y encriptación
# - Configuración de seguridad (acceso público bloqueado, SSL obligatorio)
# ==============================================================================
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.region
}

# ------------------------------------------------------------------------------
# S3 BUCKET - Almacenamiento del Terraform State
# ------------------------------------------------------------------------------
# Crea el bucket principal donde se guardarán todos los archivos .tfstate
# El versionamiento permite recuperar estados anteriores en caso de error.
# ------------------------------------------------------------------------------
resource "aws_s3_bucket" "tf_state" {
  bucket        = var.bucket_name
  force_destroy = false  // Protección: no destruir el bucket si contiene objetos

  tags = merge(var.tags, { Name = var.bucket_name })
}

# ------------------------------------------------------------------------------
# OWNERSHIP CONTROLS - Control de propiedad de objetos
# ------------------------------------------------------------------------------
# Fuerza que el dueño del bucket sea también el dueño de todos los objetos.
# Esto simplifica la gestión de permisos y previene problemas con ACLs.
# ------------------------------------------------------------------------------
resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    object_ownership = "BucketOwnerEnforced"  // El bucket owner posee todos los objetos
  }
}

# ------------------------------------------------------------------------------
# PUBLIC ACCESS BLOCK - Bloqueo de acceso público
# ------------------------------------------------------------------------------
# Asegura que el bucket NUNCA sea accesible públicamente.
# CRÍTICO: El state contiene información sensible (IPs, IDs, credenciales).
# ------------------------------------------------------------------------------
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true  // Bloquea nuevas ACLs públicas
  block_public_policy     = true  // Bloquea nuevas políticas públicas
  ignore_public_acls      = true  // Ignora ACLs públicas existentes
  restrict_public_buckets = true  // Restringe acceso público vía bucket policies
}

# ------------------------------------------------------------------------------
# VERSIONING - Versionamiento de objetos
# ------------------------------------------------------------------------------
# Mantiene versiones históricas del state file. Si alguien destruye recursos
# accidentalmente, podemos recuperar un state anterior.
# ------------------------------------------------------------------------------
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"  // Activa el versionamiento
  }
}

# ------------------------------------------------------------------------------
# ENCRYPTION - Encriptación en reposo
# ------------------------------------------------------------------------------
# Encripta todos los objetos del bucket automáticamente usando AES-256.
# ------------------------------------------------------------------------------
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"  // Algoritmo de encriptación administrado por S3
    }
  }
}

# ------------------------------------------------------------------------------
# IAM POLICY DOCUMENT - Política de seguridad SSL/TLS
# ------------------------------------------------------------------------------
# Define una política que NIEGA cualquier operación que no use SSL/TLS.
# Esto previene que datos sensibles se transmitan sin encriptar.
# ------------------------------------------------------------------------------
data "aws_iam_policy_document" "deny_insecure_transport" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"  // NIEGA explícitamente (más fuerte que "Allow")
    
    actions = ["s3:*"]  // Aplica a TODAS las operaciones de S3

    resources = [
      aws_s3_bucket.tf_state.arn,          // ARN del bucket
      "${aws_s3_bucket.tf_state.arn}/*"   // ARN de todos los objetos dentro
    ]

    principals {
      type        = "*"  // Aplica a cualquier principal (usuario, rol, servicio)
      identifiers = ["*"]
    }

    // Condición: solo niega si SecureTransport es false (no HTTPS)
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

# ------------------------------------------------------------------------------
# BUCKET POLICY - Aplicación de la política de seguridad
# ------------------------------------------------------------------------------
# Adjunta la política IAM al bucket para hacerla efectiva.
# Después de esto, cualquier intento de acceso sin HTTPS será rechazado.
# ------------------------------------------------------------------------------
resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.tf_state.id
  policy = data.aws_iam_policy_document.deny_insecure_transport.json
}