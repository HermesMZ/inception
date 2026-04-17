#!/bin/bash

SECRETS_DIR="./srcs/secrets"

# Terminal colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

# Safety: only generate if the folder does not exist or is empty
if [ -d "$SECRETS_DIR" ] && [ "$(ls -A "$SECRETS_DIR")" ]; then
    echo -e "${YELLOW}⚠️  The secrets directory is not empty. Generation aborted to avoid breaking the DB.${NC}"
    echo -e "Use 'rm -rf $SECRETS_DIR/*' if you really want to regenerate everything."
    exit 0
fi

mkdir -p "$SECRETS_DIR"

generate_password() {
    # Use /dev/urandom for real entropy
    LC_ALL=C tr -dc 'A-Za-z0-9_.\-+=@!' < /dev/urandom | head -c 32
}

echo -e "${GREEN}🔐 Generating random passwords...${NC}"
generate_password > "$SECRETS_DIR/db_root_password.txt"
generate_password > "$SECRETS_DIR/db_password.txt"
generate_password > "$SECRETS_DIR/wp_admin_password.txt"
generate_password > "$SECRETS_DIR/wp_user_password.txt"
generate_password > "$SECRETS_DIR/redis_password.txt"
generate_password > "$SECRETS_DIR/ftp_password.txt"
generate_password > "$SECRETS_DIR/portainer_password.txt"

echo -e "${GREEN}🌐 Fetching WordPress keys via official API...${NC}"
# 10s timeout to avoid blocking if no internet
WP_KEYS_RAW=$(curl -s --connect-timeout 10 https://api.wordpress.org/secret-key/1.1/salt/)

if [ -z "$WP_KEYS_RAW" ]; then
    echo -e "${RED}❌ Error: WordPress API unreachable. Generating fallback keys...${NC}"
    # Fallback if API is offline (common on restricted networks)
    keys="AUTH_KEY SECURE_AUTH_KEY LOGGED_IN_KEY NONCE_KEY AUTH_SALT SECURE_AUTH_SALT LOGGED_IN_SALT NONCE_SALT"
    for key in $keys; do
        filename=$(echo "wp_$key" | tr '[:upper:]' '[:lower:]')
        generate_password > "$SECRETS_DIR/$filename.txt"
    done
else
    # Proper extraction of keys
    keys="AUTH_KEY SECURE_AUTH_KEY LOGGED_IN_KEY NONCE_KEY AUTH_SALT SECURE_AUTH_SALT LOGGED_IN_SALT NONCE_SALT"
    for key in $keys; do
        filename=$(echo "wp_$key" | tr '[:upper:]' '[:lower:]')
        echo "$WP_KEYS_RAW" | grep "'$key'" | cut -d"'" -f4 > "$SECRETS_DIR/$filename.txt"
    done
fi

# Restrictive permissions (read/write for owner only)
chmod 600 "$SECRETS_DIR"/*.txt
# Directory access permission
chmod 700 "$SECRETS_DIR"

echo -e "${GREEN}✅ Done. Secure secrets generated in: $SECRETS_DIR${NC}"