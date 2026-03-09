#!/bin/bash
set -e

echo "============ START INIT WORDPRESS ==============="

# --- FONCTION POUR RÉCUPÉRER LES SECRETS ---
get_secret() {
    local var_name=$1
    local file_var_name="${var_name}_FILE"
    
    # On vérifie si la variable _FILE existe (priorité aux secrets)
    if [ -n "${!file_var_name:-}" ]; then
        cat "${!file_var_name}"
    else
        # Sinon on prend la variable classique
        echo "${!var_name:-}"
    fi
}

# Liste des noms de clés attendues par WordPress
KEYS="WORDPRESS_AUTH_KEY \
WORDPRESS_SECURE_AUTH_KEY \
WORDPRESS_LOGGED_IN_KEY \
WORDPRESS_NONCE_KEY \
WORDPRESS_AUTH_SALT \
WORDPRESS_SECURE_AUTH_SALT \
WORDPRESS_LOGGED_IN_SALT \
WORDPRESS_NONCE_SALT \
DB_PASSWORD \
WORDPRESS_ADMIN_PASSWORD \
WORDPRESS_USER_PASSWORD \
REDIS_PASSWORD"

echo "Configuration des Salts WordPress..."

for key in $KEYS; do
    val=$(get_secret "$key")
    if [ -z "$val" ]; then
        echo "Erreur : La clé $key est vide !"
        exit 1
    fi
    export "$key"="$val"
done

# Créer /var/www/html si nécessaire
mkdir -p /var/www/html

echo "============ ATTENTE MARIADB ==============="

# Attendre que MariaDB soit prêt
TIMEOUT=30
SECONDS=0
echo "Waiting for MariaDB..."
until mariadb -h"$WORDPRESS_DB_HOST" -u"$WORDPRESS_DB_USER" -p"$DB_PASSWORD" --ssl=0 -e "SELECT 1" >/dev/null 2>&1; do
  sleep 1
  SECONDS=$((SECONDS+1))
  if [ "$SECONDS" -ge "$TIMEOUT" ]; then
    echo "Timeout reached. MariaDB is not ready."
    exit 1
  fi
done
echo "MariaDB is ready."

# Télécharger WordPress si nécessaire
if [ ! -f "/var/www/html/wp-settings.php" ]; then
    echo "================ Téléchargement de WordPress... ================"
    cd /tmp
    curl -O https://wordpress.org/latest.tar.gz
    tar -xzf latest.tar.gz -C /var/www/html --strip-components=1
    rm latest.tar.gz
fi

echo "================ WP-CONFIG.PHP... ================"

# Attendre que Redis soit prêt
echo "Attente de Redis..."
until nc -z "${REDIS_HOST}" "${REDIS_PORT:-6379}" 2>/dev/null; do
    sleep 1
done
echo "Redis est accessible."

echo "================ GÉNÉRATION DU WP-CONFIG.PHP ================"

# On se place dans le dossier wordpress
cd /var/www/html

# On crée le fichier de base avec les accès DB
# Note : On utilise les variables locales remplies par get_secret au début du script
wp config create \
    --dbname="${WORDPRESS_DB_NAME}" \
    --dbuser="${WORDPRESS_DB_USER}" \
    --dbpass="${DB_PASSWORD}" \
    --dbhost="${WORDPRESS_DB_HOST}" \
    --path=/var/www/html --allow-root --force --quiet

# On injecte les Salts et Redis en bouclant sur tes secrets
# C'est ici que ta boucle "KEYS" du début prend tout son sens
for key in AUTH_KEY SECURE_AUTH_KEY LOGGED_IN_KEY NONCE_KEY AUTH_SALT SECURE_AUTH_SALT LOGGED_IN_SALT NONCE_SALT; do
    var_name="WORDPRESS_$key"
    wp config set "$key" "${!var_name}" --allow-root --quiet
done

# Configuration spécifique Redis et URL
wp config set WP_HOME "https://${DOMAIN_NAME}" --allow-root --quiet
wp config set WP_SITEURL "https://${DOMAIN_NAME}" --allow-root --quiet
wp config set WP_REDIS_HOST "${REDIS_HOST}" --allow-root --quiet
wp config set WP_REDIS_PORT "${REDIS_PORT:-6379}" --raw --allow-root --quiet
wp config set WP_REDIS_PASSWORD "${REDIS_PASSWORD}" --allow-root --quiet
wp config set WP_REDIS_DATABASE 0 --raw --allow-root --quiet

chmod 644 /var/www/html/wp-config.php

echo "================ INSTALLATION AUTOMATIQUE DE WORDPRESS ================"

# Vérifier si WordPress est déjà installé
if ! wp core is-installed --allow-root --path=/var/www/html 2>/dev/null; then
    echo "Installation de WordPress..."
    
    # Installer WordPress
    wp core install \
        --url="https://${DOMAIN_NAME}" \
        --title="${WORDPRESS_TITLE:-Mon Site WordPress}" \
        --admin_user="${WORDPRESS_ADMIN_USER}" \
        --admin_password="${WORDPRESS_ADMIN_PASSWORD}" \
        --admin_email="${WORDPRESS_ADMIN_EMAIL}" \
        --allow-root \
        --path=/var/www/html \
        --quiet
    
    echo "WordPress installé avec succès !"
    
    # Créer un utilisateur supplémentaire si les variables sont définies
    if [ -n "${WORDPRESS_USER}" ] && [ -n "${WORDPRESS_USER_PASSWORD}" ] && [ -n "${WORDPRESS_USER_EMAIL}" ]; then
        echo "Création de l'utilisateur ${WORDPRESS_USER}..."
        wp user create "${WORDPRESS_USER}" "${WORDPRESS_USER_EMAIL}" \
            --role=author \
            --user_pass="${WORDPRESS_USER_PASSWORD}" \
            --allow-root \
            --path=/var/www/html \
            --quiet
        echo "Utilisateur ${WORDPRESS_USER} créé avec succès !"
    fi
else
    echo "WordPress est déjà installé."
fi

echo "================ CONFIGURATION DOSSIERS ET PERMISSIONS ================"

# Créer le dossier uploads si nécessaire
mkdir -p /var/www/html/wp-content/uploads

chmod -R 777 /var/www/html/wp-content/uploads
echo "Permissions configurées pour WordPress et FTP"

echo "================ CONFIGURATION REDIS CACHE ================"

# Installer le plugin Redis Object Cache s'il n'existe pas
if ! wp plugin is-installed redis-cache --allow-root --path=/var/www/html; then
    echo "Installation du plugin Redis Object Cache..."
    wp plugin install redis-cache --activate --allow-root --path=/var/www/html
fi

# Activer Redis si pas déjà fait
if ! wp redis status --allow-root --path=/var/www/html 2>&1 | grep -q "Connected"; then
    echo "Activation du cache Redis..."
    wp redis enable --allow-root --path=/var/www/html || true
fi

echo "Redis configuré avec succès !"

echo "WordPress initialisé avec succès."

echo "Lancement de : php-fpm83"

# Lancer PHP-FPM en foreground
exec "php-fpm83" -F