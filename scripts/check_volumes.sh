#!/bin/bash
set -e

# Volume verification script for the Inception project
# Launched from Make
# This script ensures that data volumes for MariaDB and WordPress are properly created and configured with the correct permissions
# Removing and recreating volumes may be necessary in case of permission issues or corrupted data
# Replace and/or remove Portainer depending on the chosen bonuses

# Directories on the host
BASE_DATA="/home/$USER/data"
VOLUMES=("mariadb" "wordpress" "portainer")

echo "=== Preparing volumes (UID Mapping: 1000) ==="

if [ ! -d "$BASE_DATA" ]; then
	echo "Creating base directory $BASE_DATA..."
	mkdir -p "$BASE_DATA"
	chmod -R 755 "$BASE_DATA"
fi

# Create directories as the current user (UID 1000)
for vol in "${VOLUMES[@]}"; do
    if [ ! -d "$BASE_DATA/$vol" ]; then
        echo "Creating folder $vol..."
        mkdir -p "$BASE_DATA/$vol"
		chmod -R 755 "$BASE_DATA/$vol"
    fi
done

echo "[OK] Volumes synchronized with UID $(id -u)"
echo "=== Ready for docker compose up ==="