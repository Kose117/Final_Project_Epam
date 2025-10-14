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