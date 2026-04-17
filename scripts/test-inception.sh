#!/bin/bash

# Test script for the Inception project
# Checks TLS/SSL connectivity, data persistence, MariaDB network isolation,
# the connection between WordPress and MariaDB, as well as Redis and FTP bonuses
# Waits for services to finish starting before running tests

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
# -k to ignore self-signed certificate, -I for headers
if curl -k -I https://"$DOMAIN_NAME" 2>/dev/null | grep -q "200 OK"; then
    ok "HTTPS is working on $DOMAIN_NAME"
else
    ko "HTTPS connection failed"
fi

info "Checking data persistence..."
# Create a file in the volume via the container
docker exec wordpress touch /var/www/html/persistence_test
# Restart the container
cd srcs
docker compose restart wordpress > /dev/null
cd ..
# Check if the file is still there
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

# Retrieve secrets by reading files directly in the container
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

# Retrieve Redis root password from secret
REDIS_PASS=$(docker exec redis cat /run/secrets/redis_password)

if docker exec redis redis-cli -a "$REDIS_PASS" ping 2>/dev/null \
  | grep -q "PONG"; then
    ok "Redis is reachable and responding"
else
    ko "Redis is NOT reachable"
fi

info "Checking wordpress to redis connection..."

# Use the same secret on WordPress side to test the link
REDIS_PASS_WP=$(docker exec wordpress cat /run/secrets/redis_password)

if echo -e "AUTH $REDIS_PASS_WP\r\nPING\r\n" \
  | docker exec -i wordpress nc -w 2 redis 6379 \
  | grep -q "+PONG"; then
    ok "wordpress can reach redis on port 6379"
else
    ko "wordpress cannot reach redis"
fi

# ================= BONUS: FTP =================
info "Checking FTP login and file transfer..."

FTP_PASS=$(docker exec ftp cat /run/secrets/ftp_password)
info "FTP password retrieved from secret"

# Create a temporary test file
TEST_FILE="test_ftp_upload.txt"
echo "text file sent and retrieved." > "$TEST_FILE"
info "Test file created: $TEST_FILE"

# Test connection and upload/download via FTP
info "Starting FTP connection test..."
FTP_OUTPUT=$(ftp -inv localhost 2>&1 <<EOF
user ftpuser $FTP_PASS
binary
pwd
ls
cd wordpress/wp-content/uploads
put $TEST_FILE
ls -la $TEST_FILE
get $TEST_FILE new_$TEST_FILE
bye
EOF
)

echo "=== FTP OUTPUT ==="
echo "$FTP_OUTPUT"
echo "=================="

if echo "$FTP_OUTPUT" | grep -q "226 Transfer complete"; then
    info "FTP transfer completed successfully"
    
    # Check that the file was correctly downloaded
    if [ -f "new_$TEST_FILE" ]; then
        info "Downloaded file found at new_$TEST_FILE"
        
        CONTENT=$(cat "new_$TEST_FILE")
        info "Downloaded file content: '$CONTENT'"
        
        if [ "$CONTENT" = "text file sent and retrieved." ]; then
            ok "FTP upload and download successful"
            rm -f "$TEST_FILE" "$TEST_DIR/new_$TEST_FILE"
            # Clean up file on FTP server
            docker exec ftp rm -f /home/ftpuser/wordpress/wp-content/uploads/$TEST_FILE 2>/dev/null || true
            info "Cleanup completed"
        else
            ko "FTP file content mismatch. Expected: 'text file sent and retrieved.' Got: '$CONTENT'"
        fi
    else
        ko "FTP download failed - file not found at new_$TEST_FILE"
        info "Checking what's in FTP server..."
        docker exec ftp ls -la /home/ftpuser/wordpress/wp-content/uploads/
    fi
else
    ko "FTP login or transfer failed"
    echo "=== FTP ERROR DETAILS ==="
    echo "$FTP_OUTPUT" | grep -E "(550|553|530|421)"
    echo "========================="
fi

# ================= DONE =================
echo
echo -e "${GREEN}All checks passed. Inception (with bonuses) is clean ✅${NC}"
