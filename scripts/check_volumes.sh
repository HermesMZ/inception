#!/bin/bash
set -e

# Script de vérification des volumes pour le projet Inception
# Lancé depuis Make
# Ce script s'assure que les volumes de données pour MariaDB et WordPress sont correctement créés et configurés avec les permissions adéquates
# Retirer les volumes et les recréer peut être nécessaire en cas de problèmes de permissions ou de données corrompues
# Remplacer et/ou supprimer portainer en fonction des bonus choisis

# Répertoires sur le host
BASE_DATA="/home/$USER/data"
VOLUMES=("mariadb" "wordpress" "portainer")

echo "=== Préparation des volumes (UID Mapping: 1000) ==="

if [ ! -d "$BASE_DATA" ]; then
	echo "Création du répertoire de base $BASE_DATA..."
	mkdir -p "$BASE_DATA"
	chmod -R 755 "$BASE_DATA"
fi
# Création des répertoires par l'utilisateur courant (UID 1000)
for vol in "${VOLUMES[@]}"; do
    if [ ! -d "$BASE_DATA/$vol" ]; then
        echo "Création du dossier $vol..."
        mkdir -p "$BASE_DATA/$vol"
		chmod -R 755 "$BASE_DATA/$vol"
    fi
done


echo "[OK] Volumes synchronisés avec l'UID $(id -u)"
echo "=== Prêt pour docker compose up ==="