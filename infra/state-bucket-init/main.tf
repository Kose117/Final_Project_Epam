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

locals {
  bucket_arn          = aws_s3_bucket.tf_state.arn
  bucket_objects_arn  = "${aws_s3_bucket.tf_state.arn}/*"
  attach_iam_policies = length(var.iam_usernames) > 0
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
  restrict_public_buckets = true  // Restringe acceso público
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

    // Condición: niega solo si NO es HTTPS
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

# ------------------------------------------------------------------------------
# IAM POLICY - Permisos mínimos para gestionar el bucket del tfstate
# ------------------------------------------------------------------------------
# Algunos equipos utilizan usuarios IAM sin privilegios de administrador. Para
# facilitar la creación del bucket, se puede adjuntar automáticamente una
# política con los permisos mínimos requeridos (crear el bucket, aplicar
# versionamiento, encriptación, políticas y gestionar objetos del state).
# ------------------------------------------------------------------------------
data "aws_iam_policy_document" "state_bucket_access" {
  count = local.attach_iam_policies ? 1 : 0

  statement {
    sid    = "AllowBucketCreation"
    effect = "Allow"

    actions   = ["s3:CreateBucket"]
    resources = ["*"]
  }

  statement {
    sid    = "ManageBucketConfiguration"
    effect = "Allow"

    actions = [
      "s3:DeleteBucket",
      "s3:DeleteBucketPolicy",
      "s3:DeleteBucketPublicAccessBlock",
      "s3:DeleteBucketOwnershipControls",
      "s3:DeleteBucketTagging",
      "s3:GetBucketAcl",
      "s3:GetBucketLocation",
      "s3:GetBucketPolicy",
      "s3:GetBucketPolicyStatus",
      "s3:GetBucketPublicAccessBlock",
      "s3:GetBucketTagging",
      "s3:GetBucketVersioning",
      "s3:GetEncryptionConfiguration",
      "s3:ListBucket",
      "s3:ListBucketVersions",
      "s3:PutBucketAcl",
      "s3:PutBucketPolicy",
      "s3:PutBucketPublicAccessBlock",
      "s3:PutBucketOwnershipControls",
      "s3:PutBucketTagging",
      "s3:PutBucketVersioning",
      "s3:PutEncryptionConfiguration"
    ]

    resources = [
      local.bucket_arn
    ]
  }

  statement {
    sid    = "ManageStateObjects"
    effect = "Allow"

    actions = [
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:ListBucketMultipartUploads",
      "s3:ListMultipartUploadParts",
      "s3:PutObject"
    ]

    resources = [
      local.bucket_objects_arn
    ]
  }
}

resource "aws_iam_policy" "state_bucket_access" {
  count = local.attach_iam_policies ? 1 : 0

  name        = "${var.bucket_name}-state-admin"
  description = "Permisos mínimos para gestionar el bucket del Terraform state ${var.bucket_name}"
  policy      = data.aws_iam_policy_document.state_bucket_access[0].json

  tags = merge(var.tags, {
    Name = "${var.bucket_name}-state-admin"
  })
}

resource "aws_iam_user_policy_attachment" "state_bucket_access" {
  for_each = local.attach_iam_policies ? toset(var.iam_usernames) : {}

  user       = each.value
  policy_arn = aws_iam_policy.state_bucket_access[0].arn
}