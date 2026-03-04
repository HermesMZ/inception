#!/bin/bash
set -e

# --- FONCTION POUR RÉCUPÉRER LES SECRETS ---
get_secret() {
    local var_name=$1
    local file_var_name="${var_name}_FILE"
    
    if [ -n "${!file_var_name:-}" ]; then
        cat "${!file_var_name}"
    else
        echo "${!var_name:-}"
    fi
}

PASS_FILE="/tmp/portainer_pass"

echo "===== Initialisation Portainer ====="

# 1. Ajuster le GID du socket Docker
if [ -S /var/run/docker.sock ]; then
    DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)
    addgroup -g "$DOCKER_GID" docker_host 2>/dev/null || true
    addgroup portainer docker_host 2>/dev/null || true
fi

# 2. Préparation de la commande
CMD="/opt/portainer/portainer --bind :9000 --data /data"

# 3. Gestion du mot de passe admin via Secret
PORTAINER_PASS=$(get_secret "PORTAINER_PASSWORD")

if [ -n "$PORTAINER_PASS" ]; then
    echo "Secret détecté, configuration du mot de passe..."
    echo "$PORTAINER_PASS" > "$PASS_FILE"
    chown portainer:portainer "$PASS_FILE"
    chmod 600 "$PASS_FILE"
    
    CMD="$CMD --admin-password-file=$PASS_FILE"
else
    echo "⚠️ Aucun secret trouvé, l'installation manuelle sera requise au premier accès."
fi

echo "Lancement de Portainer..."

# 4. Exécution propre
exec su-exec portainer $CMD