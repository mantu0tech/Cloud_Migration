#!/bin/bash
###############################################################
# 02_import_to_rds.sh
# Import MySQL dump (.sql or .sql.gz) into AWS RDS
###############################################################

set -euo pipefail

# ── Configuration ──────────────────────────────────────────
RDS_ENDPOINT="${RDS_ENDPOINT:-database-1.cjqgwiy282it.ap-south-1.rds.amazonaws.com:3306}"
RDS_USER="${RDS_USER:-admin}"
DB_NAME="${DB_NAME:-ClickNcart}"

# CHANGE THIS to your latest dump file
DUMP_FILE="${DUMP_FILE:-$HOME/mysql-backups/ClickNcart_20260704_090857.sql.gz}"

# ── Colors ────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
step()  { echo -e "${BLUE}[STEP]${NC} $1"; }

# ── Validate inputs ────────────────────────────────────────
command -v mysql >/dev/null 2>&1 || error "mysql client not installed"

[[ -f "$DUMP_FILE" ]] || error "Dump file not found: $DUMP_FILE"

# ── Extract host & port ───────────────────────────────────
RDS_HOST="${RDS_ENDPOINT%%:*}"
RDS_PORT="${RDS_ENDPOINT##*:}"
[[ "$RDS_PORT" == "$RDS_HOST" ]] && RDS_PORT=3306

# ── Password ───────────────────────────────────────────────
read -sp "Enter RDS password for '$RDS_USER': " RDS_PASS
echo

# ── Test connection ────────────────────────────────────────
step "Testing connection to RDS..."

mysql \
  -h "$RDS_HOST" \
  -P "$RDS_PORT" \
  -u "$RDS_USER" \
  -p"$RDS_PASS" \
  --ssl-mode=REQUIRED \
  -e "SELECT 'Connection OK' AS status;" \
|| error "Cannot connect to RDS (check security group + public access)"

info "Connection successful!"

# ── Create database if not exists ─────────────────────────
step "Ensuring database exists..."

mysql \
  -h "$RDS_HOST" \
  -P "$RDS_PORT" \
  -u "$RDS_USER" \
  -p"$RDS_PASS" \
  --ssl-mode=REQUIRED \
  -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# ── Confirm import ────────────────────────────────────────
echo ""
warn "About to import: $DUMP_FILE"
echo "Target DB: $DB_NAME"
echo ""
read -p "Type YES to continue: " CONFIRM
[[ "$CONFIRM" == "YES" ]] || error "Aborted by user"

# ── Import ────────────────────────────────────────────────
step "Starting import..."

MYSQL_CMD="mysql \
  -h $RDS_HOST \
  -P $RDS_PORT \
  -u $RDS_USER \
  -p$RDS_PASS \
  --ssl-mode=REQUIRED \
  --max_allowed_packet=64M \
  $DB_NAME"

if [[ "$DUMP_FILE" == *.gz ]]; then
  gunzip -c "$DUMP_FILE" | $MYSQL_CMD
else
  $MYSQL_CMD < "$DUMP_FILE"
fi

# ── Verify ────────────────────────────────────────────────
step "Verifying import..."

mysql \
  -h "$RDS_HOST" \
  -P "$RDS_PORT" \
  -u "$RDS_USER" \
  -p"$RDS_PASS" \
  --ssl-mode=REQUIRED \
  -e "USE \`$DB_NAME\`; SHOW TABLES;"

echo ""
info "✅ IMPORT COMPLETE SUCCESSFULLY"
echo ""
echo "You can now connect using:"
echo "mysql -h $RDS_HOST -u $RDS_USER -p $DB_NAME"
