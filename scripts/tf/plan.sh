#!/usr/bin/env bash
set -euo pipefail

ENV="${1:-}"
if [[ "$ENV" != "qa" && "$ENV" != "prod" ]]; then
  echo "Uso: $0 <qa|prod>"
  exit 1
fi

BACKEND_FILE="infra/backend-config/backend.hcl"
if [[ ! -f "$BACKEND_FILE" ]]; then
  echo "No encuentro $BACKEND_FILE. Crea primero el bucket con infra/bootstrap y define backend.hcl"
  exit 1
fi

# Selecciona/crea workspace
scripts/tf/select-workspace.sh "$ENV"

# Init con backend remoto
terraform -chdir=infra init -reconfigure -backend-config="$BACKEND_FILE"

# Asegura carpeta de planes
mkdir -p infra/plans

# Plan apuntando al entrypoint del entorno
terraform -chdir=infra/env/"$ENV" fmt -recursive
terraform -chdir=infra/env/"$ENV" validate

terraform -chdir=infra/env/"$ENV" plan \
  -var-file="${ENV}.tfvars" \
  -out="../../plans/${ENV}.plan"

echo "✔ Plan guardado en infra/plans/${ENV}.plan"
