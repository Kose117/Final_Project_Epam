#!/usr/bin/env bash
set -euo pipefail

ENV="${1:-}"
if [[ "$ENV" != "qa" && "$ENV" != "prod" ]]; then
  echo "Uso: $0 <qa|prod>"
  exit 1
fi

# usamos el root de infra para que el workspace afecte el backend común
pushd infra >/dev/null

terraform init -backend=false >/dev/null
if terraform workspace list | grep -q " $ENV$"; then
  terraform workspace select "$ENV"
else
  terraform workspace new "$ENV"
fi

ACTIVE=$(terraform workspace show)
echo "✔ Workspace activo: $ACTIVE"

popd >/dev/null
