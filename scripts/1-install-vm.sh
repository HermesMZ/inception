#!/bin/bash

# script numero 1
# A lancer en root
# Script d'installation pour VM Inception Debian 12
# Ce script prépare la VM pour l'installation de Docker et de l'environnement Inception
# Il configure un utilisateur sudo, sécurise SSH, et met en place un pare-feu

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 0. Vérification root
if [ "$EUID" -ne 0 ]; then 
    log_error "Ce script doit être exécuté en ROOT"
    exit 1
fi

log_info "=== Installation de la VM Inception ==="

# 1. Mise à jour et Installation sudo
apt-get update -y
apt-get install -y sudo ftp ca-certificates curl gnupg lsb-release tree make openssh-server ufw

# 2. Configuration de l'utilisateur
echo -e "${YELLOW}--- Configuration de l'utilisateur ---${NC}"
# On essaie de deviner si un utilisateur existe déjà (le premier après root)
SUGGESTED_USER=$(awk -F: '$3 >= 1000 && $3 < 60000 { print $1 }' /etc/passwd | head -n 1)

echo -n -e "Entrez le login de l'utilisateur à ajouter au groupe sudo [Défaut: $SUGGESTED_USER] : "
read SELECTED_USER

USER_TO_ADD=${SELECTED_USER:-$SUGGESTED_USER}

if [ -z "$USER_TO_ADD" ]; then
    log_error "Aucun utilisateur spécifié. Abandon."
    exit 1
fi

if id "$USER_TO_ADD" &>/dev/null; then
    usermod -aG sudo "$USER_TO_ADD"
    log_info "Utilisateur $USER_TO_ADD ajouté au groupe sudo avec succès."
else
    log_error "L'utilisateur '$USER_TO_ADD' n'existe pas."
    exit 1
fi

# 3. Configuration SSH
log_info "Configuration SSH..."
sed -i 's/#Port 22/Port 4242/' /etc/ssh/sshd_config
sed -i 's/^Port 22/Port 4242/' /etc/ssh/sshd_config
log_info "Port SSH changé en 4242"
systemctl enable --now ssh
systemctl restart ssh

# 4. Configuration Pare-feu (UFW)
log_info "Configuration UFW..."
# --force évite "Command may disrupt network connections. Proceed? (y|n)"
ufw --force enable
ufw allow 4242/tcp
ufw allow 443/tcp
log_info "Règles UFW appliquées :"
ufw status

# 5. Nettoyage
apt-get autoremove -y && apt-get clean

log_info "=== VM prête pour l'étape suivante (docker.sh) ==="
log_info "Utilisateur configuré : $USER_TO_ADD"

# 6. Lancement automatique de 2-install-docker.sh
# On suppose que 2-install-docker.sh est dans le même dossier que ce script (1-install-vm.sh)

SCRIPT_2="./2-install-docker.sh"

if [ -f "$SCRIPT_2" ]; then
    log_info "Script 2 trouvé dans le répertoire courant."
    chmod +x "$SCRIPT_2"
    
    log_info "Lancement de 2-install-docker.sh..."
    # On passe USER_TO_ADD en tant que SUDO_USER pour le script suivant
    SUDO_USER="$USER_TO_ADD" bash "$SCRIPT_2"
else
    log_warn "Impossible de trouver $SCRIPT_2 dans $(pwd)."
    log_warn "Assure-toi d'exécuter le script 1 depuis le dossier 'scripts/' de ton projet."
fi