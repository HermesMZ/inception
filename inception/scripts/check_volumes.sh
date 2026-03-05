#!/bin/bash
set -e

# Répertoires sur le host
BASE_DATA="/home/$USER/data"
VOLUMES=("mariadb" "wordpress" "portainer")

echo "=== Préparation des volumes (UID Mapping: 1000) ==="

# Création des répertoires par l'utilisateur courant (UID 1000 par défaut sur 42)
for vol in "${VOLUMES[@]}"; do
    if [ ! -d "$BASE_DATA/$vol" ]; then
        echo "Création du dossier $vol..."
        mkdir -p "$BASE_DATA/$vol"
    fi
done

chmod -R 755 "$BASE_DATA"

echo "[OK] Volumes synchronisés avec l'UID $(id -u)"
echo "=== Prêt pour docker compose up ==="