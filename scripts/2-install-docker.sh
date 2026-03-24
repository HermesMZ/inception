#!/bin/bash

# Script d'installation de Docker
# A lancer avec sudo et pas en root direct depuis le home de l'utilisateur
# Ce script installe Docker, configure les permissions, et prépare l'environnement pour Inception
set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [ "$EUID" -ne 0 ]; then 
    log_error "Ce script doit être exécuté avec sudo"
    exit 1
fi

# Récupération du login de l'utilisateur
USER_LOGIN=${SUDO_USER:-$USER}

log_info "=== Installation de Docker ==="

# 1. Installation des dépendances Docker
log_info "Installation des dépendances système..."
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release

# 2. Configuration du dépôt Docker officiel
log_info "Configuration du dépôt Docker..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# 3. Installation de Docker
log_info "Installation de Docker Engine et Compose Plugin..."
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 4. Gestion des permissions
log_info "Configuration des groupes et permissions..."
systemctl enable --now docker
if ! getent group docker > /dev/null; then groupadd docker; fi
usermod -aG docker "$USER_LOGIN"

# 5. Limitations des logs Docker
log_info "Optimisation des logs Docker..."
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

# 6. Configuration du /etc/hosts pour le domaine local
log_info "Configuration du domaine local dans /etc/hosts..."
if ! grep -q "$USER_LOGIN.42.fr" /etc/hosts 2>/dev/null; then
    echo "127.0.0.1 $USER_LOGIN.42.fr" >> /etc/hosts
fi

# 7. Secrets
log_info "Génération des secrets..."
SECRETS_DIR="../srcs/secrets"
mkdir -p "$SECRETS_DIR"
chown -R "$USER_LOGIN":"$USER_LOGIN" "$SECRETS_DIR"
sudo -u "$USER_LOGIN" bash ./secrets.sh
log_info "Mettre à jour le fichier srcs/.env.example"
log_info "=== Installation de Docker terminée ! ==="

log_info "Virtual Box - A configurer dans les redirections de port de la VM :"
log_info "SSH : 4242"
log_info "HTTPS : 443"
log_info "Mettre à jour le fichier srcs/.env.example"

log_info "Lancement de la VM terminée. Connectez-vous avec : ssh -p 4242 $USER_TO_ADD@localhost"
