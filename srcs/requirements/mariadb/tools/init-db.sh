#!/bin/bash
set -euo pipefail

echo "===== Initializing MariaDB ====="

DATA_DIR="/var/lib/mysql"

# --- FUNCTION TO RETRIEVE SECRETS ---
get_secret() {
    local var_name=$1
    local file_var_name="${var_name}_FILE"
    
    # Check if the _FILE variable exists (secrets have priority)
    if [ -n "${!file_var_name:-}" ]; then
        cat "${!file_var_name}"
    else
        # Otherwise use the regular variable
        echo "${!var_name:-}"
    fi
}

# Retrieve passwords
ROOT_PASS=$(get_secret "MYSQL_ROOT_PASSWORD")
USER_PASS=$(get_secret "MYSQL_PASSWORD")

# Security check
if [ -z "$ROOT_PASS" ]; then
    echo "Error: MYSQL_ROOT_PASSWORD_FILE or MYSQL_ROOT_PASSWORD is not set."
    exit 1
fi

# Initialize the database if it is not already initialized
if [ ! -d "$DATA_DIR/mysql" ]; then
    echo "Initializing system tables..."
    mariadb-install-db --user=mysqluser --datadir="$DATA_DIR" --skip-test-db

    # 1. Create a temporary SQL file
    TMP_SQL="/tmp/init.sql"
    cat > $TMP_SQL <<EOF
USE mysql;
FLUSH PRIVILEGES;
DROP USER IF EXISTS '${MYSQL_USER}'@'localhost';
-- Configure root with the secret
ALTER USER 'root'@'localhost' IDENTIFIED BY '${ROOT_PASS}';
-- Create your WordPress user for external access (%)
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${USER_PASS}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOF

    echo "Running temporary MariaDB to execute setup..."
    # 2. Start MariaDB with the --init-file option
    # This executes the SQL before opening the network
    mariadbd --user=mysqluser --datadir="$DATA_DIR" --bootstrap < $TMP_SQL
    
    rm -f $TMP_SQL
fi

# Create .my.cnf file for healthcheck (very important!)
cat > /root/.my.cnf <<EOF
[client]
user=root
password=${ROOT_PASS}
EOF
chmod 600 /root/.my.cnf

echo "===== Starting MariaDB server ====="
exec mariadbd --user=mysqluser --datadir="$DATA_DIR"