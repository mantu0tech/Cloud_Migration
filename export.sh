#!/bin/bash
###############################################################
# 01_export_mysql_wsl.sh
# Export MySQL database from WSL to a compressed .sql.gz file
###############################################################

set -euo pipefail

# =========================
# Configuration
# =========================
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_HOST="${MYSQL_HOST:-127.0.0.1}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
DB_NAME="${DB_NAME:-ClickNcart}"

BACKUP_DIR="${BACKUP_DIR:-$HOME/mysql-backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

DUMP_FILE="$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.sql"
DUMP_FILE_GZ="${DUMP_FILE}.gz"

# =========================
# Colors
# =========================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# =========================
# Dependency Check
# =========================
info "Checking dependencies..."

command -v mysql >/dev/null || error "mysql client not installed."
command -v mysqldump >/dev/null || error "mysqldump not installed."
command -v gzip >/dev/null || error "gzip not installed."

mkdir -p "$BACKUP_DIR"

info "Backup directory: $BACKUP_DIR"

# =========================
# Password
# =========================
read -sp "Enter MySQL password for '$MYSQL_USER': " MYSQL_PASS
echo

# =========================
# Check Database Exists
# =========================
info "Checking database..."

mysql \
    -h"$MYSQL_HOST" \
    -P"$MYSQL_PORT" \
    -u"$MYSQL_USER" \
    -p"$MYSQL_PASS" \
    -e "USE \`$DB_NAME\`;" \
    >/dev/null 2>&1 || error "Database '$DB_NAME' not found."

# =========================
# Database Size
# =========================
info "Checking database size..."

DB_SIZE=$(mysql \
    -h"$MYSQL_HOST" \
    -P"$MYSQL_PORT" \
    -u"$MYSQL_USER" \
    -p"$MYSQL_PASS" \
    --skip-column-names \
    -e "
SELECT ROUND(SUM(data_length+index_length)/1024/1024,2)
FROM information_schema.tables
WHERE table_schema='$DB_NAME';
")

DB_SIZE=${DB_SIZE:-0}

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Database : $DB_NAME"
echo "Size     : ${DB_SIZE} MB"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

# Optional warning for very large databases
if command -v bc >/dev/null; then
    if (( $(echo "$DB_SIZE > 102400" | bc -l) )); then
        warn "Database is larger than 100 GB."
    fi
fi

# =========================
# Export
# =========================
info "Starting mysqldump..."
info "Output: $DUMP_FILE_GZ"

mysqldump \
    --host="$MYSQL_HOST" \
    --port="$MYSQL_PORT" \
    --user="$MYSQL_USER" \
    --password="$MYSQL_PASS" \
    --single-transaction \
    --routines \
    --triggers \
    --events \
    --hex-blob \
    --default-character-set=utf8mb4 \
    --set-gtid-purged=OFF \
    --no-tablespaces \
    "$DB_NAME" | gzip > "$DUMP_FILE_GZ"

# =========================
# Verify
# =========================
if [[ ! -f "$DUMP_FILE_GZ" ]]; then
    error "Export failed. Dump file was not created."
fi

DUMP_SIZE=$(du -sh "$DUMP_FILE_GZ" | cut -f1)

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Export Successful!"
echo
echo "Database : $DB_NAME"
echo "File     : $DUMP_FILE_GZ"
echo "Size     : $DUMP_SIZE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

info "You can verify the dump with:"
echo "gzip -cd \"$DUMP_FILE_GZ\" | head"

echo
info "Next step: Import into Amazon RDS."
