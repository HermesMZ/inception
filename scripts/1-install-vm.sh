#!/bin/bash

# script number 1
# Must be run as root
# Installation script for Inception VM (Debian 12)
# This script prepares the VM for Docker and the Inception environment setup
# It configures a sudo user, secures SSH, and sets up a firewall

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 0. Root check
if [ "$EUID" -ne 0 ]; then 
    log_error "This script must be run as ROOT"
    exit 1
fi

log_info "=== Installing Inception VM ==="

# 1. Update and install sudo
apt-get update -y
apt-get install -y sudo ftp ca-certificates curl gnupg lsb-release tree make openssh-server ufw

# 2. User configuration
echo -e "${YELLOW}--- User configuration ---${NC}"
# Try to guess if a user already exists (the first one after root)
SUGGESTED_USER=$(awk -F: '$3 >= 1000 && $3 < 60000 { print $1 }' /etc/passwd | head -n 1)

echo -n -e "Enter the username to add to the sudo group [Default: $SUGGESTED_USER]: "
read SELECTED_USER

USER_TO_ADD=${SELECTED_USER:-$SUGGESTED_USER}

if [ -z "$USER_TO_ADD" ]; then
    log_error "No user specified. Aborting."
    exit 1
fi

if id "$USER_TO_ADD" &>/dev/null; then
    usermod -aG sudo "$USER_TO_ADD"
    log_info "User $USER_TO_ADD successfully added to the sudo group."
else
    log_error "User '$USER_TO_ADD' does not exist."
    exit 1
fi

# 3. SSH configuration
log_info "Configuring SSH..."
sed -i 's/#Port 22/Port 4242/' /etc/ssh/sshd_config
sed -i 's/^Port 22/Port 4242/' /etc/ssh/sshd_config
log_info "SSH port changed to 4242"
systemctl enable --now ssh
systemctl restart ssh

# 4. Firewall configuration (UFW)
log_info "Configuring UFW..."
# --force avoids "Command may disrupt network connections. Proceed? (y|n)"
ufw --force enable
ufw allow 4242/tcp
ufw allow 443/tcp
log_info "Applied UFW rules:"
ufw status

# 5. Cleanup
apt-get autoremove -y && apt-get clean

log_info "=== VM ready for the next step (docker.sh) ==="
log_info "Configured user: $USER_TO_ADD"

# 6. Automatically launch 2-install-docker.sh
# We assume 2-install-docker.sh is in the same folder as this script (1-install-vm.sh)

SCRIPT_2="./2-install-docker.sh"

if [ -f "$SCRIPT_2" ]; then
    log_info "Script 2 found in the current directory."
    chmod +x "$SCRIPT_2"
    
    log_info "Launching 2-install-docker.sh..."
    # Pass USER_TO_ADD as SUDO_USER to the next script
    SUDO_USER="$USER_TO_ADD" bash "$SCRIPT_2"
else
    log_warn "Unable to find $SCRIPT_2 in $(pwd)."
    log_warn "Make sure you run script 1 from the 'scripts/' folder of your project."
fi