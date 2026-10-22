# Terraform and Ansible project

An automated two-host AWS deployment that provisions cloud infrastructure with **Terraform** and configures **Docker Engine**, **Docker Compose**, an **Nginx + Flask Notes API** stack, and a **PostgreSQL** database with automated backups using **Ansible**.

## Architecture

![System architecture](system_Architecture.drawio.png)


### Network & Security Design

| Component | Host / Scope | Exposure & Access Control | Purpose |
| :--- | :--- | :--- | :--- |
| **Nginx** (`nginx:1.27.4-alpine`) | App EC2 (`app_net`) | Publicly published on port `80` (`0.0.0.0:80->80/tcp`) | Reverse proxy forwarding HTTP requests to `http://app:8000` |
| **Notes API** (`notes-app:1.0.0`) | App EC2 (`app_net`) | **Unpublished** (`EXPOSE 8000` only); runs as non-root UID/GID `1000:1000` | Flask + `psycopg2` JSON API managing records in PostgreSQL |
| **PostgreSQL** (`postgres:16.4`) | DB EC2 | Bound exclusively to DB host private IP (`<db_private_ip>:5432:5432`); `db-sg` allows TCP `5432` **only** from `app-sg` | Relational database storing the `notes` table |
| **Persistent Storage** | DB EC2 (`/dev/nvme1n1`) | Formatted `ext4` (`LABEL=data`), mounted at `/data` via `/etc/fstab` | Stores `/data/postgres` outside container writable layers |
| **SSH Management** | Both EC2 Hosts | Restricted to `var.my_ip` (`/32` CIDR) in both security groups | Used by Ansible for host configuration and deployment |

## Repository Structure

```text
.
├── README.md
├── system_Architecture.drawio.png
├── ansible/
│   ├── ansible.cfg                        # Ansible defaults, SSH pipelining, Vault password path
│   ├── inventory.ini                      # Generated automatically from Terraform outputs (gitignored)
│   ├── site.yml                           # Main playbook (storage, docker, postgres, backup, app)
│   ├── restore.yml                        # Playbook to restore PostgreSQL from the latest backup
│   ├── group_vars/all/
│   │   ├── vars.yml                       # Non-sensitive shared variables and device paths
│   │   └── vault.yml                      # Ansible Vault encrypted database credentials (AES-256)
│   └── roles/
│       ├── storage/                       # Formats and mounts attached EBS volume at /data
│       ├── docker/                        # Installs Docker Engine, Compose plugin, enables on boot
│       ├── postgres/                      # Deploys PostgreSQL Compose stack, init.sql, restore script
│       ├── backup/                        # Configures daily pg_backup.sh cron job and retention
│       └── app/                           # Builds app image, templates Nginx/Compose, checks health
├── app/
│   ├── Dockerfile                         # Pinned Python 3.12.11 image, non-root user, healthcheck
│   ├── app.py                             # Flask JSON API (/health, GET /notes, POST /notes)
│   ├── requirements.txt                   # Pinned Flask (3.1.2) and psycopg2-binary (2.9.10)
│   └── .dockerignore
├── scripts/
│   ├── deploy.sh                          # End-to-end workflow: Terraform -> Inventory -> Ansible
│   └── generate_inventory.sh              # Populates ansible/inventory.ini from Terraform outputs
└── terraform/
    ├── main.tf                            # AWS provider (~> 6.0) and default resource tags
    ├── network.tf                         # Dedicated VPC, public subnet, IGW, and route table
    ├── app.tf                             # App EC2 instance, EBS volume, key pair, and app SG
    ├── db.tf                              # DB EC2 instance, EBS volume, and DB SG
    ├── variables.tf                       # Configurable inputs (region, my_ip, instance_type, etc.)
    ├── outputs.tf                         # Public and private IP outputs for App and DB instances
    └── terraform.tfvars.example           # Example variable file for trusted IP configuration
```

## Prerequisites

Ensure the following tools and credentials are configured on your local machine before deploying:

1. **AWS Credentials**: Configured via `aws configure` or environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`) with permissions to manage VPC, EC2, EBS, and Security Groups.
2. **Terraform**: Version `>= 1.5` installed.
3. **Ansible**: `ansible-core` installed along with the required Galaxy collections:
   ```bash
   ansible-galaxy collection install community.docker community.general ansible.posix
   ```
4. **SSH Key Pair**: An SSH key pair located at `~/.ssh/devops_lab` and `~/.ssh/devops_lab.pub` (the default paths in `terraform/variables.tf` and `ansible/ansible.cfg`). Generate one if needed:
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/devops_lab -N ""
   ```

## Deployment Instructions

### 1. Configure Your Trusted Public IP for Terraform

Copy the example variable file and set `my_ip` to your current public IPv4 address in `/32` CIDR notation:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
echo "my_ip = \"$(curl -s https://checkip.amazonaws.com)/32\"" > terraform/terraform.tfvars
```

### 2. Configure Ansible Vault Credentials

`ansible/ansible.cfg` reads the Vault password from `.vault_pass` in the repository root (which is excluded from Git via `.gitignore`).

Create your `.vault_pass` file and encrypt your database credentials in `ansible/group_vars/all/vault.yml`:

```bash
# 1. Create your local Vault password file
echo "your-strong-vault-password" > .vault_pass
chmod 600 .vault_pass

# 2. Write and encrypt your PostgreSQL credentials into ansible/group_vars/all/vault.yml
cat << 'EOF' > ansible/group_vars/all/vault.yml
---
vault_db_password: "ChangeMe_AppDbPassword123!"
vault_postgres_password: "ChangeMe_PostgresRoot123!"
EOF

ansible-vault encrypt ansible/group_vars/all/vault.yml --vault-password-file .vault_pass
```

### 3. Run the Automated Deployment Workflow

Execute the deployment script from the repository root:

```bash
./scripts/deploy.sh
```

What `./scripts/deploy.sh` performs automatically:

1. **Infrastructure Provisioning**: Runs `terraform -chdir=terraform init` and `terraform -chdir=terraform apply -auto-approve` to create the VPC (`10.0.0.0/16`), public subnet (`10.0.1.0/24`), internet gateway, route table, separate security groups (`app-sg` and `db-sg`), two Ubuntu 24.04 `t3.micro` EC2 instances, and their attached 10 GB `gp3` EBS volumes.
2. **Dynamic Inventory Generation**: Runs `./scripts/generate_inventory.sh`, which queries `terraform output` (`app_public_ip`, `db_public_ip`, `db_private_ip`) and generates `ansible/inventory.ini` with `db_host` mapped to the database host's private IP.
3. **Configuration & Container Deployment**: Runs `ansible-playbook site.yml`, which:
   - Waits for SSH connectivity and `cloud-init` completion on both hosts.
   - Formats the attached EBS volume (`/dev/nvme1n1`) as `ext4` (`LABEL=data`) and mounts it persistently at `/data` in `/etc/fstab`.
   - Installs Docker Engine and the Docker Compose v2 plugin and enables `docker.service` on boot.
   - Deploys `postgres:16.4` on the DB host (bound only to `<db_private_ip>:5432`), initializes `notesdb` and `notes_user`, and waits until the container healthcheck (`pg_isready`) reports `healthy`.
   - Configures the daily backup script (`/usr/local/bin/pg_backup.sh`), restore script (`/usr/local/bin/pg_restore.sh`), and cron schedule on the DB host.
   - Waits for PostgreSQL port `5432` to be reachable from the App host, builds `notes-app:1.0.0` (running as non-root UID/GID `1000:1000`), starts the app and `nginx:1.27.4-alpine` over the local `app_net` bridge network, and verifies `http://127.0.0.1/health` returns `200 OK` through Nginx.

## End-to-End Verification, Backup & Restore

### 1. Verify Idempotency (No Unnecessary Changes or Restarts)

```bash
# Second Terraform plan shows zero infrastructure changes
terraform -chdir=terraform plan

# Second Ansible run reports changed=0 with no container restarts or data loss
(cd ansible && ansible-playbook site.yml)
```

### 2. Test Health Check, Creating & Reading Records via Nginx

```bash
APP_IP=$(terraform -chdir=terraform output -raw app_public_ip)

# Check application & database health through Nginx
curl -i "http://${APP_IP}/health"

# Create two test notes
curl -s -X POST "http://${APP_IP}/notes" \
  -H "Content-Type: application/json" \
  -d '{"title": "First Note", "body": "Before backup"}'

curl -s -X POST "http://${APP_IP}/notes" \
  -H "Content-Type: application/json" \
  -d '{"title": "Second Note", "body": "Also backed up"}'

# List all notes
curl -s "http://${APP_IP}/notes"
```

### 3. Database Backup & Restore of Deleted Test Data

The `backup` role installs `/usr/local/bin/pg_backup.sh` and schedules a daily root cron job (`0 2 * * *`) on the database host:
- Runs `docker exec postgres pg_dump -U notes_user -d notesdb -Fc` to write compressed custom-format dumps to `/var/backups/postgres/notes_YYYYMMDD_HHMMSS.dump` on the host filesystem (outside container writable layers).
- Writes to a temporary `.tmp` file first and atomically renames on success.
- Deletes dump files older than `7` days (`backup_retention_days: 7`).

To demonstrate backing up, deleting test records, and restoring them with `ansible/restore.yml`:

```bash
APP_IP=$(terraform -chdir=terraform output -raw app_public_ip)

# 1. Trigger an immediate backup on the DB server
(cd ansible && ansible db -b -m command -a "/usr/local/bin/pg_backup.sh")

# 2. Delete all rows from the notes table to simulate accidental data loss
(cd ansible && ansible db -b -m command -a "docker exec postgres psql -U notes_user -d notesdb -c 'DELETE FROM notes;'")

# 3. Confirm the notes are gone (returns [])
curl -s "http://${APP_IP}/notes"

# 4. Run the restore playbook (/usr/local/bin/pg_restore.sh restores the latest dump)
(cd ansible && ansible-playbook restore.yml)

# 5. Verify the deleted notes are restored
curl -s "http://${APP_IP}/notes"
```

### 4. Verify Persistence Across Database Container Recreation

```bash
# Recreate the PostgreSQL container on the DB host
(cd ansible && ansible db -b -m command -a "docker compose -f /opt/postgres/docker-compose.yml up -d --force-recreate")

# Verify existing notes survive container recreation via the /data/postgres EBS volume
curl -s "http://${APP_IP}/notes"
```

### 5. Verify Database Port 5432 Is Inaccessible from the Internet

```bash
DB_IP=$(terraform -chdir=terraform output -raw db_public_ip)
nc -zv -w 5 "${DB_IP}" 5432 || echo "PASS: Port 5432 is blocked from the public internet"
```

## Cleanup

To destroy all AWS resources created by this project (`VPC`, `EC2 instances`, `EBS volumes`, `Security Groups`, `Internet Gateway`, `Route Table`, and `Key Pair`):

```bash
terraform -chdir=terraform destroy -auto-approve
```

## Known Limitations

- **HTTP Only (No TLS)**: Nginx listens on port `80` over plain HTTP because no domain name or TLS certificate is provisioned for this lab environment.
- **Public Subnet for Database Host**: As permitted by the assignment specification, both EC2 instances reside in a public subnet so Ansible can reach them directly via SSH (`var.my_ip/32`) and download apt/Docker packages without incurring NAT Gateway costs. PostgreSQL port `5432` remains completely inaccessible from the internet via both Security Group rules (`app-sg` only) and private IP socket binding (`<db_private_ip>:5432`).
- **Local Host Backups**: Daily `pg_dump` backups are written to `/var/backups/postgres` on the DB host's root EBS volume (separate from the `/data` EBS volume housing live PostgreSQL data). In production, backups would also be replicated off-host to Amazon S3.


## Attribution & External Components

- **Application Code**: The Flask Notes API (`app/app.py`) was written specifically for this assignment using standard `Flask` and `psycopg2` patterns.
- **Container Images & Modules**: Uses official Docker Hub images (`nginx:1.27.4-alpine`, `postgres:16.4`, `python:3.12.11-slim-bookworm`), the official HashiCorp AWS Terraform provider (`hashicorp/aws`), and official Ansible Galaxy collections (`community.docker`, `community.general`, `ansible.posix`).