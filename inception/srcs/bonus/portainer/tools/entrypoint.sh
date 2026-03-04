#!/bin/sh
set -e

SECRET_PATH="/run/secrets/portainer_password"
PASS_FILE="/tmp/portainer_pass"

# Ajuster le groupe docker pour matcher celui du host
DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)
groupmod -g "$DOCKER_GID" portainer 2>/dev/null || true
usermod -aG portainer portainer 2>/dev/null || true

# Construire la commande dynamiquement
CMD="/opt/portainer/portainer --bind :9000"

if [ -f "$SECRET_PATH" ]; then
    echo "Secret détecté, configuration de l'admin automatique..."
    cat "$SECRET_PATH" > "$PASS_FILE"
    CMD="$CMD --admin-password-file $PASS_FILE"
else
    echo "Pas de secret trouvé, démarrage standard..."
fi

# Exécuter en UID 1000
exec su-exec portainer sh -c "$CMD"