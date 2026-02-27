#!/bin/sh

# Script d'initialisation de Redis

set -e

echo "Starting Redis initialization..."

# Si un mot de passe est défini, l'ajouter à la configuration
if [ -n "$REDIS_PASSWORD" ]; then
    echo "Configuring Redis with password protection..."
    echo "requirepass $REDIS_PASSWORD" >> /etc/redis/redis.conf
else
    echo "Warning: Redis is running WITHOUT password protection!"
fi

mkdir -p /data/redis
chown redis:redis /data/redis
chmod 700 /data/redis

echo "Redis configuration complete. Starting server..."

# Démarrer Redis avec la configuration
exec redis-server /etc/redis/redis.conf
