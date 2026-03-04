#!/bin/bash

set -e

echo "Starting Redis initialization..."

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

# Récupération du mot de passe
REDIS_PASS=$(get_secret "REDIS_PASSWORD")

# Configuration du mot de passe dans redis.conf
if [ -n "$REDIS_PASS" ]; then
    echo "Configuring Redis with password protection..."
    # On utilise sed pour modifier la ligne existante ou on l'ajoute
    if grep -q "requirepass" /etc/redis/redis.conf; then
        sed -i "s|requirepass .*|requirepass $REDIS_PASS|g" /etc/redis/redis.conf
    else
        echo "requirepass $REDIS_PASS" >> /etc/redis/redis.conf
    fi
    
    # Sécurité supplémentaire pour Redis (liaison à toutes les interfaces pour le réseau Docker)
    sed -i "s|bind 127.0.0.1|bind 0.0.0.0|g" /etc/redis/redis.conf
    # Désactivation du mode protégé pour permettre les connexions depuis le réseau Inception
    sed -i "s|protected-mode yes|protected-mode no|g" /etc/redis/redis.conf
else
    echo "Warning: Redis is running WITHOUT password protection!"
fi

# Gestion des permissions pour le volume de données
mkdir -p /data/redis
chown redis:redis /data/redis
chmod 700 /data/redis

echo "Redis configuration complete. Starting server..."

# Lancer Redis en foreground
exec redis-server /etc/redis/redis.conf