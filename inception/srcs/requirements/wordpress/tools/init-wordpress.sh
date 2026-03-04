#!/bin/sh
set -e

echo "============ START INIT WORDPRESS ==============="

# Créer /var/www/html si nécessaire
mkdir -p /var/www/html

echo "============ ATTENTE MARIADB ==============="

# Attendre que MariaDB soit prêt
TIMEOUT=10
SECONDS=0
echo "Waiting for MariaDB..."
until mariadb -h"$WORDPRESS_DB_HOST" -u"$WORDPRESS_DB_USER" -p"$WORDPRESS_DB_PASSWORD" --ssl=0 -e "SELECT 1" >/dev/null 2>&1; do
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

# Créer wp-config.php avec Redis déjà configuré
cat > /var/www/html/wp-config.php <<EOF
<?php
define('WP_HOME','https://' . '${DOMAIN_NAME}');
define('WP_SITEURL','https://' . '${DOMAIN_NAME}');

define('DB_NAME', '${WORDPRESS_DB_NAME}');
define('DB_USER', '${WORDPRESS_DB_USER}');
define('DB_PASSWORD', '${WORDPRESS_DB_PASSWORD}');
define('DB_HOST', '${WORDPRESS_DB_HOST}');
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');

define('AUTH_KEY',         '${WORDPRESS_AUTH_KEY}');
define('SECURE_AUTH_KEY',  '${WORDPRESS_SECURE_AUTH_KEY}');
define('LOGGED_IN_KEY',    '${WORDPRESS_LOGGED_IN_KEY}');
define('NONCE_KEY',        '${WORDPRESS_NONCE_KEY}');
define('AUTH_SALT',        '${WORDPRESS_AUTH_SALT}');
define('SECURE_AUTH_SALT', '${WORDPRESS_SECURE_AUTH_SALT}');
define('LOGGED_IN_SALT',   '${WORDPRESS_LOGGED_IN_SALT}');
define('NONCE_SALT',       '${WORDPRESS_NONCE_SALT}');

// Configuration Redis
define('WP_REDIS_HOST', '${REDIS_HOST}');
define('WP_REDIS_PORT', ${REDIS_PORT:-6379});
define('WP_REDIS_PASSWORD', '${REDIS_PASSWORD}');
define('WP_REDIS_DATABASE', 0);

\$table_prefix = 'wp_';

define('WP_DEBUG', true);
define('WP_DEBUG_LOG', true);
define('WP_DEBUG_DISPLAY', true);

if ( ! defined('ABSPATH') ) {
    define('ABSPATH', __DIR__ . '/');
}

require_once ABSPATH . 'wp-settings.php';
EOF

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
        --path=/var/www/html
    
    echo "WordPress installé avec succès !"
    
    # Créer un utilisateur supplémentaire si les variables sont définies
    if [ -n "${WORDPRESS_USER}" ] && [ -n "${WORDPRESS_USER_PASSWORD}" ] && [ -n "${WORDPRESS_USER_EMAIL}" ]; then
        echo "Création de l'utilisateur ${WORDPRESS_USER}..."
        wp user create "${WORDPRESS_USER}" "${WORDPRESS_USER_EMAIL}" \
            --role=author \
            --user_pass="${WORDPRESS_USER_PASSWORD}" \
            --allow-root \
            --path=/var/www/html
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