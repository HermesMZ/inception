#!/bin/bash
set -euo pipefail

echo "===== Initialisation MariaDB ====="

DATA_DIR="/var/lib/mysql"

# Initialiser la base de données si elle n'est pas déjà initialisée
if [ ! -d "$DATA_DIR/mysql" ]; then
    echo "Initializing system tables..."
    mariadb-install-db --user=mysqluser --datadir="$DATA_DIR"

    # Démarrer MariaDB en arrière-plan temporairement sur socket uniquement
    echo "Starting temporary MariaDB server..."
    mariadbd --user=mysqluser --datadir="$DATA_DIR" --skip-networking --socket=/run/mysqld/mysqld.sock &
    MYSQL_PID=$!

    echo "Waiting for MariaDB to be ready..."
    until mariadb -uroot --socket=/run/mysqld/mysqld.sock --ssl=0 -e "SELECT 1" >/dev/null 2>&1; do
        echo "Still waiting..."
        sleep 1
    done
    echo "MariaDB is ready!"

    # Configuration initiale de la base de données
    echo "Configuring database and users..."
    mariadb -uroot --socket=/run/mysqld/mysqld.sock --ssl=0 <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
FLUSH PRIVILEGES;

CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;

CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOF


    echo "Database configuration completed!"

    # Arrêter MariaDB
    echo "Stopping temporary MariaDB server..."
    kill $MYSQL_PID
    wait $MYSQL_PID || true
    echo "Temporary server stopped."
fi

	cat > /root/.my.cnf <<EOF
[client]
user=root
password=${MYSQL_ROOT_PASSWORD}
EOF
chmod 600 /root/.my.cnf


echo "===== Starting MariaDB server ====="
exec mariadbd --user=mysqluser --datadir="$DATA_DIR"
