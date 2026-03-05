#!/bin/bash
set -euo pipefail

echo "===== Initialisation MariaDB ====="

DATA_DIR="/var/lib/mysql"

# --- FONCTION POUR RÉCUPÉRER LES SECRETS ---
get_secret() {
    local var_name=$1
    local file_var_name="${var_name}_FILE"
    
    # On vérifie si la variable _FILE existe (priorité aux secrets)
    if [ -n "${!file_var_name:-}" ]; then
        cat "${!file_var_name}"
    else
        # Sinon on prend la variable classique
        echo "${!var_name:-}"
    fi
}

# On récupère nos mots de passe
ROOT_PASS=$(get_secret "MYSQL_ROOT_PASSWORD")
USER_PASS=$(get_secret "MYSQL_PASSWORD")

# Vérification de sécurité
if [ -z "$ROOT_PASS" ]; then
    echo "Erreur : MYSQL_ROOT_PASSWORD_FILE ou MYSQL_ROOT_PASSWORD non défini."
    exit 1
fi

# Initialiser la base de données si elle n'est pas déjà initialisée
if [ ! -d "$DATA_DIR/mysql" ]; then
    echo "Initializing system tables..."
    mariadb-install-db --user=mysqluser --datadir="$DATA_DIR" --skip-test-db

    # 1. On crée un fichier SQL temporaire
    TMP_SQL="/tmp/init.sql"
    cat > $TMP_SQL <<EOF
USE mysql;
FLUSH PRIVILEGES;
-- On configure root avec le secret
ALTER USER 'root'@'localhost' IDENTIFIED BY '${ROOT_PASS}';
-- On crée ton utilisateur WordPress pour l'extérieur (%)
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${USER_PASS}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOF

    echo "Running temporary MariaDB to execute setup..."
    # 2. On lance MariaDB avec l'option --init-file
    # Cela exécute le SQL avant même d'ouvrir le réseau
    mariadbd --user=mysqluser --datadir="$DATA_DIR" --bootstrap < $TMP_SQL
    
    rm -f $TMP_SQL
fi

# Création du fichier .my.cnf pour le healthcheck (très important !)
cat > /root/.my.cnf <<EOF
[client]
user=root
password=${ROOT_PASS}
EOF
chmod 600 /root/.my.cnf

echo "===== Starting MariaDB server ====="
exec mariadbd --user=mysqluser --datadir="$DATA_DIR"