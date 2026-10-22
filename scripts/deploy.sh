#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${PROJECT_DIR}"

# ==============================================================================
# Preflight checks (Fail fast before spending money on cloud resources)
# ==============================================================================
echo "==> Running preflight checks..."
PREFLIGHT_FAILED=0

# 1. Check for .vault_pass
if [ ! -f "${PROJECT_DIR}/.vault_pass" ]; then
    echo "ERROR: Missing vault password file: ${PROJECT_DIR}/.vault_pass" >&2
    echo "       Create it by running: echo 'your_password' > .vault_pass" >&2
    PREFLIGHT_FAILED=1
fi

# 2. Check for vault.yml
if [ ! -f "${PROJECT_DIR}/ansible/group_vars/all/vault.yml" ]; then
    echo "ERROR: Missing vault variables file: ${PROJECT_DIR}/ansible/group_vars/all/vault.yml" >&2
    echo "       Create it from example: cp ansible/group_vars/all/vault.yml.example ansible/group_vars/all/vault.yml" >&2
    echo "       Then encrypt it: ansible-vault encrypt ansible/group_vars/all/vault.yml" >&2
    PREFLIGHT_FAILED=1
fi

# 3. Check for terraform.tfvars
if [ ! -f "${PROJECT_DIR}/terraform/terraform.tfvars" ]; then
    echo "ERROR: Missing terraform.tfvars at ${PROJECT_DIR}/terraform/terraform.tfvars" >&2
    echo "       Create it from example: cp terraform/terraform.tfvars.example terraform/terraform.tfvars" >&2
    PREFLIGHT_FAILED=1
fi

# 4. Check for SSH key pair
SSH_KEY="${HOME}/.ssh/devops_lab"
if [ ! -f "${SSH_KEY}" ]; then
    echo "ERROR: Missing SSH private key: ${SSH_KEY}" >&2
    echo "       Generate with: ssh-keygen -t rsa -b 4096 -f ~/.ssh/devops_lab -N ''" >&2
    PREFLIGHT_FAILED=1
fi

if [ ! -f "${SSH_KEY}.pub" ]; then
    echo "ERROR: Missing SSH public key: ${SSH_KEY}.pub" >&2
    PREFLIGHT_FAILED=1
fi

if [ "${PREFLIGHT_FAILED}" -ne 0 ]; then
    echo "==> Preflight checks failed! Aborting before provisioning any resources." >&2
    exit 1
fi
echo "==> Preflight checks passed."

# Ensure required Ansible collections are installed
if [ -f "${PROJECT_DIR}/ansible/requirements.yml" ]; then
    echo "==> Checking Ansible collections..."
    ansible-galaxy collection install -r "${PROJECT_DIR}/ansible/requirements.yml"
fi

echo "==> Provisioning infrastructure with Terraform"
terraform -chdir=terraform init -input=false
terraform -chdir=terraform apply -auto-approve -input=false

echo "==> Generating Ansible inventory"
bash "${PROJECT_DIR}/scripts/generate_inventory.sh"

echo "==> Running Ansible"
cd "${PROJECT_DIR}/ansible"
ansible-playbook site.yml

echo "==> Deployment completed"
