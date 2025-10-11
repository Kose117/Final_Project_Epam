#!/usr/bin/env bash
set -euo pipefail

: "${AWS_PROFILE:=default}"
: "${AWS_REGION:=us-east-1}"

echo "AWS_PROFILE=$AWS_PROFILE"
echo "AWS_REGION=$AWS_REGION"

aws sts get-caller-identity >/dev/null
echo "✔ AWS credentials OK"
