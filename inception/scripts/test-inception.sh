#!/bin/bash

# ================= COLORS =================
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
NC="\033[0m"

# ================= UTILS =================
ok() {
    echo -e "${GREEN}[OK]${NC} $1"
}

ko() {
    echo -e "${RED}[KO]${NC} $1"
    exit 1
}

info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

info "Waiting for services to be healthy..."
while [ "$(docker ps | grep -c "starting")" -gt 0 ]; do
    echo -n "."
    sleep 2
done
echo -e " ${GREEN}Ready!${NC}"

# ================= CHECKS =================
info "Checking Nginx TLS/SSL connectivity..."
DOMAIN_NAME=$(docker exec wordpress printenv DOMAIN_NAME)
# -k pour ignorer le certificat auto-signé, -I pour les headers
if curl -k -I https://"$DOMAIN_NAME" 2>/dev/null | grep -q "200 OK"; then
    ok "HTTPS is working on $DOMAIN_NAME"
else
    ko "HTTPS connection failed"
fi

info "Checking data persistence..."
# On crée un fichier dans le volume via le conteneur
docker exec wordpress touch /var/www/html/persistence_test
# On redémarre le conteneur
cd srcs
docker compose restart wordpress > /dev/null
cd ..
# On vérifie si le fichier est toujours là
if docker exec wordpress ls /var/www/html/persistence_test &>/dev/null; then
    ok "Volumes are persistent"
    docker exec wordpress rm /var/www/html/persistence_test
else
    ko "Volume data lost after restart"
fi

info "Checking MariaDB network isolation..."
if [ "$(docker inspect mariadb --format='{{range $p, $conf := .NetworkSettings.Ports}}{{$p}}{{end}}')" == "" ]; then
    ok "MariaDB is isolated (no ports exposed)"
else
    ko "MariaDB exposes ports to the host!"
fi

# ================= WORDPRESS -> MARIADB =================
info "Checking wordpress to mariadb connection..."

# On récupère les secrets en lisant les fichiers directement dans le conteneur
DB_USER=$(docker exec wordpress printenv WORDPRESS_DB_USER)
DB_PASS=$(docker exec wordpress cat /run/secrets/db_password)

if docker exec wordpress mariadb \
    -hmariadb \
    -u"$DB_USER" \
    -p"$DB_PASS" \
    --ssl=0 \
    -e "SELECT 1" &>/dev/null; then
    ok "wordpress can connect to mariadb"
else
    ko "wordpress cannot connect to mariadb"
fi

# ================= BONUS: REDIS =================
info "Checking redis availability..."

# On récupère le mot de passe root de Redis depuis le secret
REDIS_PASS=$(docker exec redis cat /run/secrets/redis_password)

if docker exec redis redis-cli -a "$REDIS_PASS" ping 2>/dev/null \
  | grep -q "PONG"; then
    ok "Redis is reachable and responding"
else
    ko "Redis is NOT reachable"
fi

info "Checking wordpress to redis connection..."

# On utilise le même secret côté WordPress pour tester le lien
REDIS_PASS_WP=$(docker exec wordpress cat /run/secrets/redis_password)

if echo -e "AUTH $REDIS_PASS_WP\r\nPING\r\n" \
  | docker exec -i wordpress nc -w 2 redis 6379 \
  | grep -q "+PONG"; then
    ok "wordpress can reach redis on port 6379"
else
    ko "wordpress cannot reach redis"
fi

# ================= BONUS: FTP =================
info "Checking FTP login..."

# Récupération du secret FTP
FTP_PASS=$(docker exec ftp cat /run/secrets/ftp_password)

if timeout 5s bash -c \
  "echo -e 'USER ftpuser\r\nPASS $FTP_PASS\r\nQUIT\r\n' | docker exec -i ftp nc localhost 21" \
  | grep -q "230 Login successful"; then
    ok "FTP login works with ftpuser"
else
    ko "FTP login failed"
fi

# ================= DONE =================
echo
echo -e "${GREEN}All checks passed. Inception (with bonuses) is clean ✅${NC}"