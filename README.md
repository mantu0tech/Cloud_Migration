# ☁️ Enterprise Cloud Migration — AWS Data Migration Project

> **Migrating structured & unstructured data from Windows / WSL Ubuntu to AWS using real DevOps tooling**

---

## 📋 Project Overview

This project demonstrates a **complete cloud migration pipeline** covering two data types:

| Data Type | Source | Tool | Destination |
|---|---|---|---|
| **Structured** | MySQL on WSL Ubuntu | mysqldump / AWS DMS | Amazon RDS for MySQL |
| **Unstructured** | Windows / EC2 Files | AWS CLI / AWS DataSync | Amazon S3 |

---

## 🗂️ Repository Structure

```
Enterprise-Cloud-Migration/
├── aws-rds-migration/               ← Terraform IaC for RDS + DMS
│   ├── terraform/
│   │   ├── environments/prod/
│   │   │   ├── main.tf              ← Entry point, wires all modules
│   │   │   ├── variables.tf         ← All input variables
│   │   │   ├── terraform.tfvars     ← Your values (add to .gitignore!)
│   │   │   └── outputs.tf           ← RDS endpoint output
│   │   └── modules/
│   │       ├── vpc/                 ← VPC, subnets, NAT, route tables
│   │       ├── security/            ← Security groups for RDS, DMS
│   │       ├── rds/                 ← Amazon RDS MySQL instance
│   │       └── dms/                 ← AWS DMS (>100GB migrations)
│   └── scripts/
│       ├── 01_export_mysql_wsl.sh   ← Export MySQL from WSL to .sql.gz
│       └── 02_import_to_rds.sh      ← Import .sql.gz into RDS
├── docs/
│   ├── structured_data_migration.docx    ← Full guide with screenshots
│   └── unstructured_data_migration.docx  ← Full guide with screenshots
├── db.sql                           ← Sample ClickNcart eCommerce database
├── .gitignore
└── README.md                        ← This file
```

---

## 🏗️ Architecture

### Structured Data (MySQL → RDS)

```
WSL Ubuntu (MySQL 8.4.9)
        │
        ├── Architecture 1 (<100 GB)
        │       └── mysqldump --single-transaction
        │               └── .sql.gz → SSL → Amazon RDS MySQL
        │
        └── Architecture 2 (>100 GB, zero downtime)
                └── AWS DMS Replication Instance
                        ├── Full Load (existing data)
                        └── CDC (ongoing changes)
                                └── → Amazon RDS MySQL
```

### Unstructured Data (Files → S3)

```
Windows / WSL
        │
        ├── Method A — AWS CLI (quick, one-time)
        │       └── aws s3 cp --recursive folder/ s3://bucket/
        │
        └── Method B — AWS DataSync (enterprise, scheduled)
                └── Windows EC2
                        └── Amazon FSx (Windows File Server)
                                └── AWS DataSync Task
                                        └── → Amazon S3
```

---

## ⚙️ Prerequisites

### On Windows (host machine)
- AWS CLI installed and configured (`aws configure`)
- WSL 2 with Ubuntu installed
- Remote Desktop client (built into Windows)

### In WSL Ubuntu
```bash
sudo apt update
sudo apt install awscli -y
sudo apt install mysql-client mysql-server -y
sudo apt install pv bc gzip wget -y
```

### AWS Account
- IAM user with: AmazonRDSFullAccess, AmazonS3FullAccess, AWSDatabaseMigrationServiceFullAccess
- For Terraform: additionally AdministratorAccess (or equivalent)

---

## 🚀 Quick Start

### Part 1 — Structured Data (MySQL → RDS)

#### Option A: Script-based (mysqldump)

```bash
# 1. Load sample database into local WSL MySQL
wget https://raw.githubusercontent.com/mantu0tech/Fullstack-application/refs/heads/main/db.sql
mysql -u root -p < db.sql

# 2. Set your DB name
export DB_NAME="ClickNcart"

# 3. Export from local MySQL
chmod +x ./scripts/01_export_mysql_wsl.sh
./scripts/01_export_mysql_wsl.sh
# → Creates ~/mysql-backups/ClickNcart_TIMESTAMP.sql.gz

# 4. Set RDS endpoint (from terraform output or AWS Console)
export RDS_ENDPOINT="your-rds-endpoint.rds.amazonaws.com:3306"
export DUMP_FILE="$HOME/mysql-backups/ClickNcart_TIMESTAMP.sql.gz"

# 5. Import to RDS
./scripts/02_import_to_rds.sh
```

#### Option B: Terraform + DMS (production-grade)

```bash
# 1. Configure your values
cd aws-rds-migration/terraform/environments/prod
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars   # fill in your IP, DB name, passwords

# 2. Deploy infrastructure
terraform init
terraform plan
terraform apply

# 3. For DMS (>100 GB), set create_dms = true and apply again
# terraform apply (DMS task starts automatically)
```

#### Key WSL MySQL Config (required for DMS)

```bash
# Allow external connections
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
# Change: bind-address = 127.0.0.1
# To:     bind-address = 0.0.0.0

sudo systemctl restart mysql

# Enable binary logging (for CDC)
# Add to [mysqld] section:
# log_bin = /var/log/mysql/mysql-bin.log
# binlog_format = ROW
# server-id = 1
```

---

### Part 2 — Unstructured Data (Files → S3)

#### Method A: AWS CLI (fastest)

```bash
# From Windows CMD or PowerShell
aws s3 ls                                          # verify connection
aws s3 mb s3://your-bucket-name                    # create bucket
aws s3 cp --recursive YourFolder/ s3://your-bucket-name/
aws s3 ls s3://your-bucket-name/                   # verify upload

# Delete test bucket
aws s3 rb s3://your-bucket-name --force
```

#### Method B: AWS DataSync + FSx (enterprise)

1. Create S3 bucket (`aws s3 mb s3://migration-fsx-window`)
2. Create Security Group (ports 445/SMB, 3389/RDP)
3. Create AWS Managed Microsoft AD (`datasync.local`)
4. Create Amazon FSx for Windows File Server (32 GiB, Single-AZ)
5. Launch Windows EC2 (t3.medium) → connect via RDP
6. Configure EC2 DNS to use AD IP addresses
7. Mount FSx share: `\\fs-xxxx.datasync.local\share`
8. Copy data to FSx share
9. Create DataSync Task: FSx (source) → S3 (destination)
10. Run task → verify in S3 Console

---

## 🔐 Security Best Practices

| Practice | Implementation |
|---|---|
| Encryption in transit | `--ssl-mode=REQUIRED` on all MySQL connections |
| Encryption at rest | RDS storage encrypted with KMS; S3 SSE-S3 |
| Least privilege IAM | Dedicated DataSync-S3-Policy, DMS IAM role |
| Security groups | RDS port 3306 open only to your IP (not 0.0.0.0/0) |
| No public S3 | Block Public Access enabled on all buckets |
| SSL certificate | AWS global-bundle.pem used for RDS connections |
| Backups | RDS automated backups, 7-day retention |

---

## 🗃️ Sample Database Schema

The `db.sql` file contains a sample **ClickNcart eCommerce** database with 8 tables:

| Table | Rows | Description |
|---|---|---|
| customers | 15 | Customer profiles |
| products | 10 | Product catalog |
| orders | 15 | Order headers |
| order_items | 22 | Order line items |
| employees | 10 | Staff records |
| departments | 7 | Department list |
| inventory_logs | 5 | Stock movement logs |
| audit_trail | 3 | System audit records |

---

## 🔧 Troubleshooting

### Structured (MySQL/RDS)

| Issue | Fix |
|---|---|
| `Access denied` on mysqldump | `GRANT SELECT, LOCK TABLES, SHOW VIEW, EVENT, TRIGGER ON *.* TO 'root'@'localhost';` |
| Cannot connect to RDS | Check Security Group — add your public IP on port 3306 |
| `max_allowed_packet` error | Add `--max_allowed_packet=64M` to mysql import command |
| DMS source connection fails | Check `bind-address=0.0.0.0` in mysqld.cnf, restart MySQL |
| RDS refuses connection | Set Public accessibility = Yes in RDS Modify |

### Unstructured (S3/DataSync)

| Issue | Fix |
|---|---|
| `NoSuchBucket` error | Run `aws s3 mb s3://bucket-name` first |
| `AccessDenied` on upload | Check IAM policy has `s3:PutObject` permission |
| FSx cannot connect | Verify EC2 DNS points to AD IP addresses, flush DNS |
| DataSync task fails | Check security group has port 445 (SMB) open |
| AD creation fails | Ensure 2 subnets in different AZs selected |

---

## 📄 Documentation

| Document | Contents |
|---|---|
| `docs/structured_data_migration.docx` | Complete step-by-step guide for MySQL → RDS with all screenshots (mysqldump + DMS methods) |
| `docs/unstructured_data_migration.docx` | Complete step-by-step guide for Files → S3 with all screenshots (AWS CLI + DataSync/FSx methods) |

---

## 💰 Cost Estimate

| Service | Approximate Cost |
|---|---|
| RDS db.t3.medium | ~$0.068/hour (~$49/month) |
| AWS DMS dms.t3.small | ~$0.045/hour during migration only |
| S3 Standard storage | ~$0.023/GB/month |
| DataSync transfer | $0.0125/GB transferred |
| FSx Windows (32 GiB) | ~$0.23/GB/month |
| AWS Managed AD (Standard) | ~$0.05/hour |

> **Tip:** Terminate DMS, FSx, and AD immediately after migration completes. Only RDS and S3 are needed ongoing.

---

## 👨‍💻 Author

Built as part of the **Enterprise Cloud Migration** DevOps project.  
Tools used: AWS CLI · Terraform · MySQL · AWS DMS · AWS DataSync · Amazon FSx · WSL Ubuntu · Windows PowerShell

---

## 📝 License

This project is for educational and demonstration purposes.
