#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${PROJECT_DIR}"

echo "==> Provisioning infrastructure with Terraform"
terraform -chdir=terraform init -input=false
terraform -chdir=terraform apply -auto-approve -input=false

echo "==> Generating Ansible inventory"
./scripts/generate_inventory.sh

echo "==> Waiting for SSH on both servers"
for output in app_public_ip db_public_ip; do
  ip="$(terraform -chdir=terraform output -raw "${output}")"
  until nc -z -w 5 "${ip}" 22; do
    echo "    ${ip} not ready, retrying in 5s..."
    sleep 5
  done
done

echo "==> Running Ansible"
cd ansible
ansible-playbook site.yml

echo "==> Deployment completed"