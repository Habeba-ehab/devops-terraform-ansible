#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${PROJECT_DIR}"

echo "==> Provisioning infrastructure with Terraform"
terraform -chdir=terraform init -input=false
terraform -chdir=terraform apply -auto-approve -input=false

echo "==> Generating Ansible inventory"
bash "${PROJECT_DIR}/scripts/generate_inventory.sh"

echo "==> Running Ansible"
cd "${PROJECT_DIR}/ansible"
ansible-playbook site.yml

echo "==> Deployment completed"