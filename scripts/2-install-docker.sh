#!/bin/bash

# Docker installation script
# Must be run with sudo, not directly as root, from the user's home directory
# This script installs Docker, configures permissions, and prepares the environment for Inception
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [ "$EUID" -ne 0 ]; then 
    log_error "This script must be run with sudo"
    exit 1
fi

# Retrieve the user's login
USER_LOGIN=${SUDO_USER:-$USER}

log_info "=== Installing Docker ==="

# 1. Install Docker dependencies
log_info "Installing system dependencies..."
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release

# 2. Set up the official Docker repository
log_info "Setting up Docker repository..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# 3. Install Docker
log_info "Installing Docker Engine and Compose Plugin..."
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 4. Permissions management
log_info "Configuring groups and permissions..."
systemctl enable --now docker
if ! getent group docker > /dev/null; then groupadd docker; fi
usermod -aG docker "$USER_LOGIN"

# 5. Limit Docker logs
log_info "Optimizing Docker logs..."
cat <<EOF > /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
systemctl restart docker

# 6. Configure /etc/hosts for local domain
log_info "Configuring local domain in /etc/hosts..."
if ! grep -q "$USER_LOGIN.42.fr" /etc/hosts 2>/dev/null; then
    echo "127.0.0.1 $USER_LOGIN.42.fr" >> /etc/hosts
fi

# 7. Secrets
log_info "Generating secrets..."
SECRETS_DIR="../srcs/secrets"
mkdir -p "$SECRETS_DIR"
chown -R "$USER_LOGIN":"$USER_LOGIN" "$SECRETS_DIR"
sudo -u "$USER_LOGIN" bash ./secrets.sh
log_info "Update the file srcs/.env.example"
log_info "=== Docker installation complete! ==="

log_info "VirtualBox - To configure in the VM port forwarding settings:"
log_info "SSH: 4242"
log_info "HTTPS: 443"
log_info "Update the file srcs/.env.example"

log_info "VM setup complete. Connect with: ssh -p 4242 $USER_TO_ADD@localhost"