#!/usr/bin/env bash
set -euo pipefail

ENV="${1:-}"
if [[ "$ENV" != "qa" && "$ENV" != "prod" ]]; then
  echo "Uso: $0 <qa|prod>"
  exit 1
fi

PLAN_FILE="infra/plans/${ENV}.plan"
if [[ ! -f "$PLAN_FILE" ]]; then
  echo "No existe $PLAN_FILE. Ejecuta scripts/tf/plan.sh $ENV primero."
  exit 1
fi

read -rp "Vas a APPLY en entorno '$ENV'. Escribe exactamente '$ENV' para continuar: " CONF
if [[ "$CONF" != "$ENV" ]]; then
  echo "Abortado."
  exit 1
fi

terraform -chdir=infra apply "$PLAN_FILE"
echo "✔ Apply completado para $ENV"
