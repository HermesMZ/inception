#!/bin/bash

# Dossier de destination
SECRETS_DIR="../srcs/secrets"
mkdir -p "$SECRETS_DIR"

# Couleurs pour le terminal
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

generate_password() {
    LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32
}

echo -e "${GREEN}Génération des mots de passe...${NC}"
generate_password > "$SECRETS_DIR/db_root_password.txt"
generate_password > "$SECRETS_DIR/db_password.txt"
generate_password > "$SECRETS_DIR/wp_admin_password.txt"
generate_password > "$SECRETS_DIR/wp_user_password.txt"
generate_password > "$SECRETS_DIR/redis_password.txt"
generate_password > "$SECRETS_DIR/ftp_password.txt"
generate_password > "$SECRETS_DIR/portainer_password.txt"

echo -e "${GREEN}Récupération des clés WordPress via API...${NC}"
WP_KEYS_RAW=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)

if [ -z "$WP_KEYS_RAW" ]; then
    echo -e "${RED}Erreur : API WordPress injoignable.${NC}"
    exit 1
fi

# Extraction des clés pour correspondre à docker-compose
keys="AUTH_KEY SECURE_AUTH_KEY LOGGED_IN_KEY NONCE_KEY AUTH_SALT SECURE_AUTH_SALT LOGGED_IN_SALT NONCE_SALT"

for key in $keys; do
    filename=$(echo "wp_$key" | tr '[:upper:]' '[:lower:]')
    echo "$WP_KEYS_RAW" | grep "'$key'" | cut -d"'" -f4 > "$SECRETS_DIR/$filename.txt"
done

chmod 600 "$SECRETS_DIR"/*.txt
echo -e "${GREEN}✅ Terminé. 15 secrets générés dans $SECRETS_DIR${NC}"