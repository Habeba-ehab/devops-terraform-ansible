#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="${PROJECT_DIR}/terraform"
ANSIBLE_DIR="${PROJECT_DIR}/ansible"

echo "==> Provisioning infrastructure with Terraform"
cd "${TERRAFORM_DIR}"
terraform init -input=false
terraform apply -auto-approve -input=false

echo "==> Generating Ansible inventory"
"${PROJECT_DIR}/scripts/generate_inventory.sh"

echo "==> Waiting for SSH on both servers"
for output in app_public_ip db_public_ip; do
  ip="$(terraform output -raw "${output}")"
  until nc -z -w 5 "${ip}" 22; do
    echo "    ${ip} not ready, retrying in 5s..."
    sleep 5
  done
done

echo "==> Running Ansible"
cd "${ANSIBLE_DIR}"
ansible-playbook site.yml

echo "==> Deployment completed"