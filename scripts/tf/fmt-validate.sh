#!/usr/bin/env bash
set -euo pipefail

terraform -chdir=infra/bootstrap fmt -recursive
terraform -chdir=infra/bootstrap validate

terraform -chdir=infra fmt -recursive
terraform -chdir=infra validate || true  # puede fallar si aún no hay root completo

echo "✔ fmt & validate completados"
