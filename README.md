# 🚀 MySQL Migration: Amazon EC2 → Azure Database for MySQL
### A Practical Step-by-Step Guide | Try It Once, You'll Love It!

---

## 🗺️ COMPLETE ROADMAP

```
PHASE 1 → Install & Configure MySQL on Amazon EC2 (Ubuntu)
PHASE 2 → Create Sample Database on EC2
PHASE 3 → Create Azure Database for MySQL (Target)
PHASE 4 → Set Up Azure Database Migration Service (DMS)
PHASE 5 → Run the Migration (Full Load + CDC)
PHASE 6 → Verify & Cutover
```

---

## ✅ PHASE 1 — Install & Configure MySQL on Amazon EC2

### Step 1: Launch EC2 Instance
1. Go to **AWS Console → EC2 → Launch Instance**
2. Choose **Ubuntu Server 22.04 LTS**
3. Instance type: `t2.micro` (free tier is fine for practice)
4. In **Security Group**, add an **Inbound Rule**:
   - Type: `MySQL/Aurora`
   - Port: `3306`
   - Source: `0.0.0.0/0` *(open for migration — restrict after)*
5. Launch and **connect to your EC2 instance via SSH**

### Step 2: Install MySQL Server

```bash
sudo apt update && sudo apt install mysql-server mysql-client -y
```

### Step 3: Create a Migration User

```bash
sudo mysql
```

Run these SQL commands inside MySQL:

```sql
CREATE USER 'migration'@'%' IDENTIFIED BY 'Migration@123';
GRANT ALL PRIVILEGES ON *.* TO 'migration'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
```

### Step 4: Verify the User Was Created

```sql
SELECT user, host, plugin
FROM mysql.user
WHERE user = 'migration';
```

### Step 5: Test Login with Migration User

```bash
mysql -u migration -p
# Enter password: Migration@123
```

---

## ✅ PHASE 2 — Create Sample Database on EC2

### Step 1: Create a SQL File

```bash
nano db.sql
```

Paste this content:

```sql
CREATE DATABASE company_db;
USE company_db;

CREATE TABLE employees (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100),
    department VARCHAR(50),
    salary DECIMAL(10,2),
    hire_date DATE
);

INSERT INTO employees (name, department, salary, hire_date) VALUES
('Alice Johnson', 'Engineering', 85000.00, '2020-01-15'),
('Bob Smith', 'Marketing', 65000.00, '2019-03-22'),
('Carol White', 'HR', 55000.00, '2021-07-10'),
('David Brown', 'Engineering', 90000.00, '2018-11-05'),
('Eve Davis', 'Finance', 75000.00, '2022-02-28');

CREATE TABLE products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(100),
    category VARCHAR(50),
    price DECIMAL(8,2),
    stock_quantity INT
);

INSERT INTO products (product_name, category, price, stock_quantity) VALUES
('Laptop Pro X', 'Electronics', 1299.99, 150),
('Wireless Mouse', 'Accessories', 29.99, 500),
('USB-C Hub', 'Accessories', 49.99, 300),
('Monitor 4K', 'Electronics', 599.99, 75),
('Keyboard Mechanical', 'Accessories', 89.99, 200);
```

Save: `Ctrl+O` → Enter → `Ctrl+X`

### Step 2: Import the Database

```bash
mysql -u migration -p < db.sql
```

### Step 3: Verify the Data

```bash
mysql -u migration -p
```

```sql
USE company_db;
SELECT * FROM employees;
SELECT * FROM products;
```

You should see **5 employees** and **5 products** ✅

---

## ✅ PHASE 3 — Create Azure Database for MySQL (Target)

### Step 1: Go to Azure Portal
👉 https://portal.azure.com — log in with your Azure account

### Step 2: Create the MySQL Flexible Server

1. Click **"+ Create a resource"**
2. Search **"Azure Database for MySQL"** → Click **Create**
3. Choose **"Flexible Server"** → Click **Create**

### Step 3: Fill in the Details

| Field | Value |
|---|---|
| Subscription | Your subscription |
| Resource Group | Create new → `mysql-migration-rg` |
| Server name | `mycompany-mysql-server` *(must be globally unique)* |
| Region | East US *(or nearest to you)* |
| MySQL Version | **8.0** |
| Workload type | **Development** *(cheapest for practice)* |
| Admin username | `azureadmin` |
| Password | `Azure@Admin1234` |

### Step 4: Configure Networking

1. Click **"Networking"** tab
2. Connectivity method → **"Public access"**
3. ✅ Check **"Allow public access from any Azure service"**
4. Click **"+ Add current client IP address"**

### Step 5: Review & Create

Click **"Review + Create"** → **"Create"**

⏳ Wait **5–10 minutes** for deployment

---

## ✅ PHASE 4 — Set Up Azure Database Migration Service (DMS)

### Step 1: Enable Binary Logging on EC2 MySQL

This is **critical** for CDC (Change Data Capture) to work.

```bash
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
```

Find the `[mysqld]` section and add:

```ini
server-id       = 1
log_bin         = mysql-bin
binlog_format   = ROW
expire_logs_days = 7
binlog_row_image = FULL
```

Save and restart MySQL:

```bash
sudo systemctl restart mysql
```

### Step 2: Allow Remote Connections (if needed)

Check the bind-address setting:

```bash
sudo grep bind-address /etc/mysql/mysql.conf.d/mysqld.cnf
```

If it shows `127.0.0.1`, change it to allow all:

```bash
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
```

Change:
```
bind-address = 127.0.0.1
```
To:
```
bind-address = 0.0.0.0
```

Restart MySQL:

```bash
sudo systemctl restart mysql
```

Test remote connection:

```bash
mysql -h <YOUR_EC2_PUBLIC_IP> -P 3306 -u migration -p
```

### Step 3: Create DMS in Azure Portal

1. In Azure Portal → Click **"+ Create a resource"**
2. Search **"Azure Database Migration Service"** → Click **Create**

| Field | Value |
|---|---|
| Service name | `mysql-dms-service` |
| Resource Group | `mysql-migration-rg` |
| Location | Same region as your Azure MySQL server |
| Pricing tier | **Premium: 4 vCores** *(required for CDC/online migration)* |

3. Click **"Review + Create"** → **"Create"**

⏳ Wait **10–15 minutes**

---

## ✅ PHASE 5 — Run the Migration

### Step 1: Create a Migration Project in DMS

1. Go to your DMS resource in Azure Portal
2. Click **"+ New Migration Project"**

| Field | Value |
|---|---|
| Project name | `company-db-migration` |
| Source server type | **MySQL** |
| Target server type | **Azure Database for MySQL** |
| Migration activity type | **Online data migration** *(Full Load + CDC)* |

3. Click **"Create and run activity"**

### Step 2: Configure Source (EC2 MySQL)

| Field | Value |
|---|---|
| Source server name | Your **EC2 Public IP** |
| Server port | `3306` |
| User name | `migration` |
| Password | `Migration@123` |
| SSL Mode | `None` *(for testing)* |

### Step 3: Configure Target (Azure MySQL)

| Field | Value |
|---|---|
| Target server name | `mycompany-mysql-server.mysql.database.azure.com` |
| User name | `azureadmin` |
| Password | `Azure@Admin1234` |

### Step 4: Select Database to Migrate

- Source DB: **`company_db`**
- Target DB: **`company_db`**
- Click **Next**

### Step 5: Select Tables

- Select all tables: **employees**, **products**
- Click **Next** → **"Run Migration"**

### Step 6: Monitor Migration

DMS Dashboard will show:
- ✅ **Full Load** — copies all existing data
- ✅ **CDC Running** — captures real-time ongoing changes

---

## 🔧 Troubleshooting

### Problem: DMS can't connect to EC2 MySQL

```bash
# Check MySQL is listening on all interfaces
sudo netstat -tlnp | grep 3306

# Confirm bind-address is 0.0.0.0
sudo grep bind-address /etc/mysql/mysql.conf.d/mysqld.cnf
```

### Problem: Large packet / table sync error

Run on **both EC2 and Azure MySQL**:

```sql
SHOW VARIABLES LIKE 'max_allowed_packet';
SET GLOBAL max_allowed_packet = 16777216;
```

### Problem: Binary logging not working

```sql
SHOW VARIABLES LIKE 'log_bin';
-- Should show: ON
SHOW VARIABLES LIKE 'binlog_format';
-- Should show: ROW
```

---

## ✅ PHASE 6 — Verify & Cutover

### Step 1: Connect to Azure MySQL and Verify

Use **MySQL Workbench** or any MySQL client:

| Field | Value |
|---|---|
| Hostname | `mycompany-mysql-server.mysql.database.azure.com` |
| Username | `azureadmin` |
| Password | `Azure@Admin1234` |
| Port | `3306` |

Run these queries:

```sql
USE company_db;
SELECT * FROM employees;
SELECT * FROM products;
SELECT COUNT(*) FROM employees;   -- Should return 5
SELECT COUNT(*) FROM products;    -- Should return 5
```

### Step 2: Test CDC is Working

Insert a new row in **EC2 MySQL**:

```sql
USE company_db;
INSERT INTO employees (name, department, salary, hire_date)
VALUES ('Frank Miller', 'Engineering', 95000, '2024-01-01');
```

Check **Azure MySQL** — the new row should appear within seconds ✅

### Step 3: Perform Final Cutover

1. **Stop all writes** to EC2 MySQL (stop your app or block connections)
2. In DMS → click **"Start Cutover"**
3. Wait for **"Pending changes: 0"**
4. Click **"Confirm Cutover"**
5. Update your application's **connection string** to point to Azure ✅

**Migration Complete! 🎉**

---

## 🔒 Security Best Practices

| Practice | Action |
|---|---|
| Encrypt data in transit | Use SSL when connecting to Azure MySQL |
| Azure AD access control | Set up Azure AD users in the Azure MySQL portal |
| Enable backups | Azure MySQL auto-backup is enabled by default — verify in portal |
| Monitor | Enable **Azure Monitor + Alerts** on your MySQL server |
| Least privilege | Use the `migration` user only during migration — revoke after |
| Lock down EC2 | After migration, restrict port 3306 in EC2 Security Group |

---

## 📋 Quick Reference

| Item | Value |
|---|---|
| EC2 MySQL User | `migration` / `Migration@123` |
| Azure MySQL Server | `mycompany-mysql-server.mysql.database.azure.com` |
| Azure Admin User | `azureadmin` / `Azure@Admin1234` |
| Database Name | `company_db` |
| Tables | `employees`, `products` |
| DMS Service | `mysql-dms-service` |
| Resource Group | `mysql-migration-rg` |

---

> 💡 **Pro Tip:** For production migrations, always do a **dry run** first with a copy of your data before running on live systems.
