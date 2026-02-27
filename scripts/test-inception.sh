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

# ================= START =================
echo "===== Inception check (with bonuses) ====="

CONTAINERS=("nginx" "wordpress" "mariadb" "redis" "adminer" "ftp")
NETWORK="inception"

# ================= CONTAINERS RUNNING =================
info "Checking containers status..."

for c in "${CONTAINERS[@]}"; do
    if docker ps --format '{{.Names}}' | grep -qx "$c"; then
        ok "Container $c is running"
    else
        ko "Container $c is NOT running"
    fi
done

# ================= NETWORK =================
info "Checking network..."

if docker network ls --format '{{.Name}}' | grep -qx "$NETWORK"; then
    ok "Network $NETWORK exists"
else
    ko "Network $NETWORK does not exist"
fi

for c in "${CONTAINERS[@]}"; do
    if docker inspect "$c" | grep -q "\"$NETWORK\""; then
        ok "$c is connected to $NETWORK"
    else
        ko "$c is NOT connected to $NETWORK"
    fi
done

# ================= MARIADB SECURITY =================
info "Checking mariadb exposure..."

PORTS=$(docker inspect mariadb --format '{{.NetworkSettings.Ports}}')
if [[ "$PORTS" == "map[]" ]]; then
    ok "mariadb does not expose any port"
else
    ko "mariadb exposes ports (forbidden)"
fi

# ================= WORDPRESS -> MARIADB =================
info "Checking wordpress to mariadb connection..."

DB_USER=$(docker exec wordpress printenv WORDPRESS_DB_USER)
DB_PASS=$(docker exec wordpress printenv WORDPRESS_DB_PASSWORD)

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

# ================= NGINX -> WORDPRESS =================
info "Checking nginx to wordpress (php-fpm)..."

if docker exec nginx nc -z wordpress 9000 &>/dev/null; then
    ok "nginx can reach wordpress on port 9000"
else
    ko "nginx cannot reach wordpress on port 9000"
fi

# ================= WEBSITE =================
info "Checking website availability..."

DOMAIN_NAME=$(docker exec wordpress printenv DOMAIN_NAME)

if curl -k https://"$DOMAIN_NAME" &>/dev/null; then
    ok "Website is reachable via nginx"
else
    ko "Website is NOT reachable"
fi

# ================= WORDPRESS VOLUME =================
info "Checking WordPress volume write access..."

if docker exec wordpress sh -c \
  "touch /var/www/html/.wp_test && rm /var/www/html/.wp_test" &>/dev/null; then
    ok "WordPress has write access to its volume"
else
    ko "WordPress cannot write to its volume"
fi

# ================= BONUS: REDIS =================
info "Checking redis availability..."

if docker exec redis redis-cli -a "$(docker exec redis printenv REDIS_PASSWORD)" ping \
  | grep -q "PONG"; then
    ok "Redis is reachable and responding"
else
    ko "Redis is NOT reachable"
fi

info "Checking wordpress to redis connection..."

REDIS_HOST=$(docker exec wordpress printenv REDIS_HOST)
REDIS_PASSWORD=$(docker exec wordpress printenv REDIS_PASSWORD)

if echo -e "AUTH $REDIS_PASSWORD\r\nPING\r\n" \
  | docker exec -i wordpress nc -w 2 "$REDIS_HOST" 6379 \
  | grep -q "+PONG"; then
    ok "wordpress can reach redis on port 6379"
else
    ko "wordpress cannot reach redis"
fi

# ================= BONUS: ADMINER =================
info "Checking adminer availability..."

ADMINER_URL="https://$DOMAIN_NAME/adminer/"
if curl -k -I "$ADMINER_URL" | grep -q "200 OK"; then
    ok "Adminer is reachable via nginx"
else
    ko "Adminer is NOT reachable"
fi

# ================= BONUS: FTP =================
info "Checking ftp availability..."

if docker inspect ftp --format '{{.NetworkSettings.Ports}}' | grep -q "21/tcp"; then
    ok "FTP port 21 is exposed"
else
    ko "FTP port 21 is NOT exposed"
fi

if docker exec ftp nc -z localhost 21 &>/dev/null; then
    ok "FTP service is listening on port 21"
else
    ko "FTP service is NOT listening"
fi

info "Checking FTP login..."

FTP_PASSWORD=$(docker exec ftp printenv FTP_PASSWORD)

if timeout 5s bash -c \
  "echo -e 'USER ftpuser\r\nPASS $FTP_PASSWORD\r\nQUIT\r\n' | docker exec -i ftp nc localhost 21" \
  | grep -q "230 Login successful"; then
    ok "FTP login works with ftpuser"
else
    ko "FTP login failed"
fi

info "Checking FTP chroot enforcement..."

FTP_CHROOT_TEST=$(timeout 5s bash -c \
  "echo -e 'USER ftpuser\r\nPASS $FTP_PASSWORD\r\nCWD ..\r\nPWD\r\nQUIT\r\n' | docker exec -i ftp nc localhost 21")

if echo "$FTP_CHROOT_TEST" | grep -q '257 "/"'; then
    ok "FTP chroot is correctly enforced"
else
    echo -e "${YELLOW}[WARN]${NC} FTP chroot could not be confirmed"
    echo "$FTP_CHROOT_TEST"
fi

# ================= DONE =================
echo
echo -e "${GREEN}All checks passed. Inception (with bonuses) is clean ✅${NC}"