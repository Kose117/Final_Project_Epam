#!/usr/bin/env bash
set -euo pipefail

ENV="${1:-}"
if [[ "$ENV" != "qa" && "$ENV" != "prod" ]]; then
  echo "Uso: $0 <qa|prod>"
  exit 1
fi

scripts/tf/select-workspace.sh "$ENV"

echo "⚠  Vas a ejecutar DESTROY en '$ENV'. Esto es irreversible."
read -rp "Escribe 'DESTROY $ENV' para continuar: " CONF
if [[ "$CONF" != "DESTROY $ENV" ]]; then
  echo "Abortado."
  exit 1
fi

terraform -chdir=infra/env/"$ENV" destroy -var-file="${ENV}.tfvars"
