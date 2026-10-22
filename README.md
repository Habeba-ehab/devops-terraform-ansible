# DevOps Terraform & Ansible Infrastructure

Automated AWS infrastructure provisioning with **Terraform** and configuration management with **Ansible** for a containerized Notes application with PostgreSQL.

---

## Prerequisites

- **Terraform** (>= 1.5.0)
- **Ansible** (>= 2.15.0)
- **AWS CLI** configured with appropriate credentials
- **SSH Key Pair**: `~/.ssh/devops_lab` and `~/.ssh/devops_lab.pub`

---

## Setup & Deployment Guide

### 1. Generate SSH Key Pair (if not already present)
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/devops_lab -N ""
```

### 2. Configure Terraform Variables
Copy the example file and update it with your public IP address:
```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```
Edit `terraform/terraform.tfvars`:
```hcl
my_ip = "YOUR_PUBLIC_IP/32"
```

### 3. Set Up Ansible Vault
1. Create `.vault_pass` in the project root containing your secret vault password:
   ```bash
   echo "your_vault_password" > .vault_pass
   chmod 600 .vault_pass
   ```

2. Copy the example vault file:
   ```bash
   cp ansible/group_vars/all/vault.yml.example ansible/group_vars/all/vault.yml
   ```

3. Encrypt `vault.yml` with Ansible Vault:
   ```bash
   # From project root:
   ansible-vault encrypt ansible/group_vars/all/vault.yml --vault-password-file .vault_pass
   
   # Or from ansible/group_vars/all:
   # ansible-vault encrypt vault.yml
   ```

### 4. Install Required Ansible Collections
Install the required collections (`community.docker`, `community.general`, `ansible.posix`):
```bash
ansible-galaxy collection install -r ansible/requirements.yml
```

### 5. Deploy Infrastructure and Services
Run the automated deployment script (includes preflight checks to prevent failed runs after spending money on AWS resources):
```bash
./scripts/deploy.sh
```

---

## Database Backup & Restore Operations

### Trigger an Immediate Backup
From the `ansible/` directory:
```bash
cd ansible
ansible db -b -m command -a "/usr/local/bin/pg_backup.sh"
```

### Simulate Accidental Data Loss (Test)
```bash
cd ansible
ansible db -b -m command -a "docker exec postgres psql -U notes_user -d notesdb -c 'DELETE FROM notes;'"
```

### Restore Database from Latest Backup
```bash
cd ansible
ansible-playbook restore.yml
```
