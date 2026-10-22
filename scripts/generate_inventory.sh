#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${PROJECT_DIR}"

APP_IP=$(terraform -chdir=terraform output -raw app_public_ip)
DB_IP=$(terraform -chdir=terraform output -raw db_public_ip)
DB_PRIVATE_IP=$(terraform -chdir=terraform output -raw db_private_ip)

cat > ansible/inventory.ini <<INV_EOF
[app]
${APP_IP} ansible_host=${APP_IP} ansible_user=ubuntu db_host=${DB_PRIVATE_IP}

[db]
${DB_IP} ansible_host=${DB_IP} ansible_user=ubuntu

[all:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_private_key_file=~/.ssh/devops_lab
INV_EOF

echo "Inventory generated:"
cat ansible/inventory.ini