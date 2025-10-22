# ==============================================================================
# BACKEND CONFIGURATION - Remote State Storage
# ==============================================================================
# Este archivo configura el backend remoto de Terraform para almacenar el state en AWS S3 con state locking nativo
#
# IMPORTANTE: Este archivo debe ser compartido por TODO el equipo.
# Todos deben usar la misma configuracion para colaborar sin conflictos.
# ==============================================================================

# Nombre del bucket S3 donde se almacenaran los state files
# Crea el bucket siguiendo el Paso 1 del README y reemplaza el valor de ejemplo.
bucket = "movie-analyst-tfstate"

# Prefijo para organizar states por workspace
# Estructura resultante:
#   - Workspace "qa":   s3://bucket/env/qa/terraform.tfstate
#   - Workspace "prod": s3://bucket/env/prod/terraform.tfstate
workspace_key_prefix = "env"

# Ruta base dentro del bucket para el state file
# Con workspaces, la ruta final sera: env/{workspace}/terraform.tfstate
key = "root/terraform.tfstate"

# Region AWS donde esta ubicado el bucket (us-east-1 si sigues la guia paso a paso)
region = "us-east-1"

# Habilita state locking nativo en S3
# Esto crea un archivo .tflock junto al state para prevenir cambios concurrentes
use_lockfile = true
