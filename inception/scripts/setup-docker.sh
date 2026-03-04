#!/bin/bash

# Script numéro 3
# Script de configuration du projet Inception
# A lancer depuis l'utilisateur (sans sudo)
set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Utilisation de l'utilisateur courant
USER_LOGIN=$USER

log_info "=== Configuration du projet Inception ==="

# 1. Création de l'arborescence (Standard Inception)
# On utilise /home/$USER_LOGIN/inception pour éviter les conflits de droits
PROJECT_DIR="/home/$USER_LOGIN/inception"
log_info "Création de la structure dans $PROJECT_DIR..."

mkdir -p "$PROJECT_DIR/srcs/requirements/mariadb/conf" \
         "$PROJECT_DIR/srcs/requirements/mariadb/tools" \
         "$PROJECT_DIR/srcs/requirements/nginx/conf" \
         "$PROJECT_DIR/srcs/requirements/nginx/tools" \
         "$PROJECT_DIR/srcs/requirements/wordpress/conf" \
         "$PROJECT_DIR/secrets" \
         "$PROJECT_DIR/srcs/requirements/wordpress/tools"

# 2. Création des répertoires de volumes (Points de montage)
log_info "Création des dossiers de volumes..."
mkdir -p "/home/$USER_LOGIN/data/mariadb"
mkdir -p "/home/$USER_LOGIN/data/wordpress"

sudo chown -R 100:101 /home/$USER_LOGIN/data/mariadb
sudo chmod 750 /home/$USER_LOGIN/data/mariadb

# 3. Makefile
log_info "Configuration du template Makefile..."

cat <<'EOF' > "$PROJECT_DIR/Makefile"
NAME = inception
COMPOSE = docker compose -f srcs/docker-compose.yml

all: up

up:
	$(COMPOSE) up --build -d

down:
	$(COMPOSE) down

stop:
	$(COMPOSE) stop

restart:
	$(COMPOSE) down
	$(COMPOSE) up --build -d

logs:
	$(COMPOSE) logs

ps:
	$(COMPOSE) ps

clean:
	$(COMPOSE) down -v

fclean: clean
	docker system prune -af

re: fclean all

.PHONY: all up down stop restart logs ps clean fclean re
EOF

# 4. docker-compose.yml
log_info "Configuration du template docker-compose.yml..."
cat <<'EOF' > "$PROJECT_DIR/srcs/docker-compose.yml"
services:
  mariadb:
    build: ./requirements/mariadb
    container_name: mariadb
  wordpress:
    build: ./requirements/wordpress
    container_name: wordpress
  nginx:
    build: ./requirements/nginx
    container_name: nginx
EOF

# 5. Dockerfiles minimum pour chaque service
log_info "Création des Dockerfiles minimum pour chaque service..."
# Mariadb Dockerfile
cat <<'EOF' > "$PROJECT_DIR/srcs/requirements/mariadb/Dockerfile"
FROM	alpine:3.22
EOF

# Wordpress Dockerfile
cat <<'EOF' > "$PROJECT_DIR/srcs/requirements/wordpress/Dockerfile"
FROM	debian:bullseye
EOF

# Nginx Dockerfile
cat <<'EOF' > "$PROJECT_DIR/srcs/requirements/nginx/Dockerfile"
FROM	alpine:3.22
EOF

log_info "=== Configuration du projet terminée ! ==="
log_info "Ton projet est prêt dans : $PROJECT_DIR"
log_info "Ton domaine est prêt : https://$USER_LOGIN.42.fr"
