#!/bin/bash
set -e

echo "============ START INIT WORDPRESS ==============="

# --- FUNCTION TO RETRIEVE SECRETS ---
get_secret() {
    local var_name=$1
    local file_var_name="${var_name}_FILE"
    
    # Check if the _FILE variable exists (priority to secrets)
    if [ -n "${!file_var_name:-}" ]; then
        cat "${!file_var_name}"
    else
        # Otherwise use the regular variable
        echo "${!var_name:-}"
    fi
}

# List of key names expected by WordPress
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

echo "Configuring WordPress Salts..."

for key in $KEYS; do
    val=$(get_secret "$key")
    if [ -z "$val" ]; then
        echo "Error: Key $key is empty!"
        exit 1
    fi
    export "$key"="$val"
done

# Create /var/www/html if needed
mkdir -p /var/www/html

echo "============ WAITING FOR MARIADB ==============="

# Wait for MariaDB to be ready
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

# Download WordPress if needed
if [ ! -f "/var/www/html/wp-settings.php" ]; then
    echo "================ Downloading WordPress... ================"
    cd /tmp
    curl -O https://wordpress.org/latest.tar.gz
    tar -xzf latest.tar.gz -C /var/www/html --strip-components=1
    rm latest.tar.gz
fi

echo "================ WP-CONFIG.PHP... ================"

# Wait for Redis to be ready
echo "Waiting for Redis..."
until nc -z "${REDIS_HOST}" "${REDIS_PORT:-6379}" 2>/dev/null; do
    sleep 1
done
echo "Redis is reachable."

echo "================ GENERATING WP-CONFIG.PHP ================"

# Move to the WordPress directory
cd /var/www/html

# Create the base config file with DB access
# Note: uses variables filled by get_secret at the beginning
wp config create \
    --dbname="${WORDPRESS_DB_NAME}" \
    --dbuser="${WORDPRESS_DB_USER}" \
    --dbpass="${DB_PASSWORD}" \
    --dbhost="${WORDPRESS_DB_HOST}" \
    --path=/var/www/html --allow-root --force --quiet

# Inject Salts and Redis config using the KEYS loop
for key in AUTH_KEY SECURE_AUTH_KEY LOGGED_IN_KEY NONCE_KEY AUTH_SALT SECURE_AUTH_SALT LOGGED_IN_SALT NONCE_SALT; do
    var_name="WORDPRESS_$key"
    wp config set "$key" "${!var_name}" --allow-root --quiet
done

# Redis and URL configuration
wp config set WP_HOME "https://${DOMAIN_NAME}" --allow-root --quiet
wp config set WP_SITEURL "https://${DOMAIN_NAME}" --allow-root --quiet
wp config set WP_REDIS_HOST "${REDIS_HOST}" --allow-root --quiet
wp config set WP_REDIS_PORT "${REDIS_PORT:-6379}" --raw --allow-root --quiet
wp config set WP_REDIS_PASSWORD "${REDIS_PASSWORD}" --allow-root --quiet
wp config set WP_REDIS_DATABASE 0 --raw --allow-root --quiet

chmod 644 /var/www/html/wp-config.php

echo "================ AUTOMATIC WORDPRESS INSTALLATION ================"

# Check if WordPress is already installed
if ! wp core is-installed --allow-root --path=/var/www/html 2>/dev/null; then
    echo "Installing WordPress..."
    
    # Install WordPress
    wp core install \
        --url="https://${DOMAIN_NAME}" \
        --title="${WORDPRESS_TITLE:-My WordPress Site}" \
        --admin_user="${WORDPRESS_ADMIN_USER}" \
        --admin_password="${WORDPRESS_ADMIN_PASSWORD}" \
        --admin_email="${WORDPRESS_ADMIN_EMAIL}" \
        --allow-root \
        --path=/var/www/html \
        --quiet
    
    echo "WordPress successfully installed!"
    
    # Create an additional user if variables are defined
    if [ -n "${WORDPRESS_USER}" ] && [ -n "${WORDPRESS_USER_PASSWORD}" ] && [ -n "${WORDPRESS_USER_EMAIL}" ]; then
        echo "Creating user ${WORDPRESS_USER}..."
        wp user create "${WORDPRESS_USER}" "${WORDPRESS_USER_EMAIL}" \
            --role=author \
            --user_pass="${WORDPRESS_USER_PASSWORD}" \
            --allow-root \
            --path=/var/www/html \
            --quiet
        echo "User ${WORDPRESS_USER} successfully created!"
    fi
else
    echo "WordPress is already installed."
fi

echo "================ DIRECTORY AND PERMISSIONS SETUP ================"

# Create uploads directory if needed
mkdir -p /var/www/html/wp-content/uploads

chmod -R 777 /var/www/html/wp-content/uploads
echo "Permissions configured for WordPress and FTP"

echo "================ REDIS CACHE SETUP ================"

# Install Redis Object Cache plugin if not present
if ! wp plugin is-installed redis-cache --allow-root --path=/var/www/html; then
    echo "Installing Redis Object Cache plugin..."
    wp plugin install redis-cache --activate --allow-root --path=/var/www/html
fi

# Enable Redis if not already active
if ! wp redis status --allow-root --path=/var/www/html 2>&1 | grep -q "Connected"; then
    echo "Enabling Redis cache..."
    wp redis enable --allow-root --path=/var/www/html || true
fi

echo "Redis successfully configured!"

echo "WordPress successfully initialized."

echo "Starting: php-fpm83"

# Start PHP-FPM in foreground
exec "php-fpm83" -F