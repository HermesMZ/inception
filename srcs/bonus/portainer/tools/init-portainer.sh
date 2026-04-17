#!/bin/bash
set -e

# --- FUNCTION TO RETRIEVE SECRETS ---
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

echo "===== Initializing Portainer ====="

# 1. Adjust Docker socket GID
if [ -S /var/run/docker.sock ]; then
    DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)
    addgroup -g "$DOCKER_GID" docker_host 2>/dev/null || true
    addgroup portainer docker_host 2>/dev/null || true
fi

# 2. Prepare the command
CMD="/opt/portainer/portainer --bind :9000 --data /data"

# 3. Handle admin password via Secret
PORTAINER_PASS=$(get_secret "PORTAINER_PASSWORD")

if [ -n "$PORTAINER_PASS" ]; then
    echo "Secret detected, configuring password..."
    echo "$PORTAINER_PASS" > "$PASS_FILE"
    chown portainer:portainer "$PASS_FILE"
    chmod 600 "$PASS_FILE"
    
    CMD="$CMD --admin-password-file=$PASS_FILE"
else
    echo "⚠️ No secret found, manual setup will be required on first access."
fi

echo "Starting Portainer..."

# 4. Clean execution
exec su-exec portainer $CMD