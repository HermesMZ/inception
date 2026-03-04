#!/bin/bash
set -e

# Répertoires sur le host
MARIADB_DIR="/home/$USER/data/mariadb"
WP_DIR="/home/$USER/data/wordpress"
PORTAINER_DIR="/home/$USER/data/portainer"

# UID/GID pour le conteneur (par exemple 1000 = ton user host)
MYSQL_UID=1000
MYSQL_GID=1000

WP_UID=1000
WP_GID=1000

echo "=== Vérification et préparation des volumes ==="

# --- MariaDB ---
if [ ! -d "$MARIADB_DIR" ]; then
    echo "Création du dossier MariaDB..."
    mkdir -p "$MARIADB_DIR"
    # Fixer permissions pour le conteneur
    chown -R $MYSQL_UID:$MYSQL_GID "$MARIADB_DIR"
    chmod 750 "$MARIADB_DIR"
    echo "[OK] MariaDB volume ready"
fi


# --- WordPress ---
if [ ! -d "$WP_DIR" ]; then
    echo "Création du dossier WordPress..."
    mkdir -p "$WP_DIR"
    chown -R $WP_UID:$WP_GID "$WP_DIR"
    chmod -R 755 "$WP_DIR"
    echo "[OK] WordPress volume ready"
fi

# --- Portainer ---
if [ ! -d "$PORTAINER_DIR" ]; then
    echo "Création du dossier Portainer..."
    mkdir -p "$PORTAINER_DIR"
    chown -R $WP_UID:$WP_GID "$PORTAINER_DIR"
    chmod -R 755 "$PORTAINER_DIR"
    echo "[OK] Portainer volume ready"
fi

echo "=== Tous les volumes sont prêts ==="
