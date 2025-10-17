variable "region" {
  description = "Región AWS del bucket del tfstate"
  type        = string
}

variable "bucket_name" {
  description = "Nombre (único global) del bucket S3 para el tfstate"
  type        = string
}

variable "tags" {
  description = "Etiquetas comunes"
  type        = map(string)
  default     = { 
    Project   = "movie-analyst"
    ManagedBy = "terraform"
    Scope     = "state"
  }
}
variable "iam_usernames" {
  description = "Lista de usuarios IAM a los que se adjuntará la política mínima para gestionar el bucket del tfstate"
  type        = list(string)
  default     = []
}