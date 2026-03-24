#!/bin/bash

SECRETS_DIR="../srcs/secrets"
SECRETS_OWNER="${SUDO_USER:-$USER}"

# Couleurs pour le terminal
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

# Sécurité : On ne génère que si le dossier n'existe pas ou est vide
if [ -d "$SECRETS_DIR" ] && [ "$(ls -A "$SECRETS_DIR")" ]; then
    echo -e "${YELLOW}⚠️  Le dossier des secrets n'est pas vide. Génération annulée pour éviter de casser la DB.${NC}"
    echo -e "Utilisez 'rm -rf $SECRETS_DIR/*' si vous voulez vraiment tout régénérer."
    exit 0
fi

mkdir -p "$SECRETS_DIR"

generate_password() {
    # On utilise /dev/urandom pour une entropie réelle
    LC_ALL=C tr -dc 'A-Za-z0-9_.\-+=@!' < /dev/urandom | head -c 32
}

echo -e "${GREEN}🔐 Génération des mots de passe aléatoires...${NC}"
generate_password > "$SECRETS_DIR/db_root_password.txt"
generate_password > "$SECRETS_DIR/db_password.txt"
generate_password > "$SECRETS_DIR/wp_admin_password.txt"
generate_password > "$SECRETS_DIR/wp_user_password.txt"
generate_password > "$SECRETS_DIR/redis_password.txt"
generate_password > "$SECRETS_DIR/ftp_password.txt"
generate_password > "$SECRETS_DIR/portainer_password.txt"

echo -e "${GREEN}🌐 Récupération des clés WordPress via API officielle...${NC}"
# Timeout de 10s pour ne pas bloquer si pas d'internet
WP_KEYS_RAW=$(curl -s --connect-timeout 10 https://api.wordpress.org/secret-key/1.1/salt/)

if [ -z "$WP_KEYS_RAW" ]; then
    echo -e "${RED}❌ Erreur : API WordPress injoignable. Génération de clés de secours...${NC}"
    # Fallback si l'API est offline (fréquent sur certains réseaux restreints)
    keys="AUTH_KEY SECURE_AUTH_KEY LOGGED_IN_KEY NONCE_KEY AUTH_SALT SECURE_AUTH_SALT LOGGED_IN_SALT NONCE_SALT"
    for key in $keys; do
        filename=$(echo "wp_$key" | tr '[:upper:]' '[:lower:]')
        generate_password > "$SECRETS_DIR/$filename.txt"
    done
else
    # Extraction propre des clés
    keys="AUTH_KEY SECURE_AUTH_KEY LOGGED_IN_KEY NONCE_KEY AUTH_SALT SECURE_AUTH_SALT LOGGED_IN_SALT NONCE_SALT"
    for key in $keys; do
        filename=$(echo "wp_$key" | tr '[:upper:]' '[:lower:]')
        echo "$WP_KEYS_RAW" | grep "'$key'" | cut -d"'" -f4 > "$SECRETS_DIR/$filename.txt"
    done
fi

# Permissions restrictives (Lecture/Ecriture pour le proprio uniquement)
chmod 600 "$SECRETS_DIR"/*.txt
# Permission d'accès au dossier
chmod 700 "$SECRETS_DIR"

# Si lancé via sudo, on rend explicitement les secrets au vrai utilisateur
if id -u "$SECRETS_OWNER" > /dev/null 2>&1; then
    chown "$SECRETS_OWNER":"$SECRETS_OWNER" "$SECRETS_DIR" "$SECRETS_DIR"/*.txt
fi

echo -e "${GREEN}✅ Terminé. Secrets sécurisés générés dans : $SECRETS_DIR${NC}"