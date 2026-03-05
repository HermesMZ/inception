# Inception - User Documentation

This document explains how to use the Inception infrastructure as an end user or system administrator.

## Table of Contents

1. [Services Overview](#services-overview)
2. [Starting and Stopping](#starting-and-stopping)
3. [Accessing Services](#accessing-services)
4. [Managing Credentials](#managing-credentials)
5. [Verifying Service Health](#verifying-service-health)
6. [Common Tasks](#common-tasks)
7. [Troubleshooting](#troubleshooting)

---

## Services Overview

The Inception infrastructure provides the following services:

### Core Services

| Service | Purpose | Port(s) |
|---------|---------|---------|
| **NGINX** | Web server & reverse proxy with TLS | 443 (HTTPS) |
| **WordPress** | Content Management System | Internal (via NGINX) |
| **MariaDB** | Database system | Internal only |

### Bonus Services

| Service | Purpose | Access |
|---------|---------|--------|
| **Redis** | WordPress caching | Internal only |
| **FTP Server** | File transfer for WordPress | 21 (FTP), 21000-21010 (passive) |
| **Adminer** | Database management interface | https://domain/adminer |
| **Static Site** | Personal CV website | https://domain/cv |
| **Portainer** | Docker container management | https://domain:9443 |

---

## Starting and Stopping

### Prerequisites

Ensure you have:
- Docker Engine installed and running
- Proper permissions to run Docker commands
- The domain name configured in `/etc/hosts` (for local) or DNS (for production)

### Starting the Infrastructure

```bash
cd inception
make
```

This command will:
1. Build all Docker images (first time only)
2. Create necessary networks
3. Initialize services in the correct order
4. Wait for all services to be healthy

**Expected output:**
```
Creating network "inception"...
Building mariadb...
Building wordpress...
Building nginx...
Starting containers...
All services are up and running!
```

### Stopping the Infrastructure

**Graceful shutdown** (keeps data):
```bash
make down
```

**Stop without removing** (can restart quickly):
```bash
make stop
```

**Complete cleanup** (removes everything including data):
```bash
make fclean
```

⚠️ **Warning**: `make fclean` will delete all data including the database!

### Restarting Services

```bash
make restart
```

Or for a complete rebuild:
```bash
make re
```

---

## Accessing Services

### Main Website (WordPress)

**URL**: `https://zobeiri.42.fr`

**Admin Panel**: `https://zobeiri.42.fr/wp-admin`

**Default credentials**:
- Username: `admin`
- Password: See secrets file (see [Managing Credentials](#managing-credentials))

### Database Management (Adminer)

**URL**: `https://zobeiri.42.fr/adminer`

**Login information**:
- System: `MySQL`
- Server: `mariadb`
- Username: `wordpress`
- Password: See `secrets/db_password.txt`
- Database: `wordpress`

### Personal CV Site

**URL**: `https://zobeiri.42.fr/cv`

This is a static website, no authentication required.

### Container Management (Portainer)

**URL**: `https://zobeiri.42.fr:9443`

**First access**: You'll need to set an admin password.

**Subsequent access**: Use the password you created.

### FTP Access

**Connection details**:
```
Host: zobeiri.42.fr
Port: 21
Username: ftpuser
Password: See secrets/ftp_password.txt
Protocol: FTP (explicit TLS recommended)
```

**Available directory**: `/home/ftpuser/wordpress`

---

## Managing Credentials

### Location of Credentials

All passwords are stored in the `inception/srcs/secrets/` directory:

```
secrets/
├── db_password.txt          # WordPress database user password
├── db_root_password.txt     # MariaDB root password
├── portainer_password.txt   # Portainer admin password
├── redis_password.txt       # Redis authentication password
└── ftp_password.txt        # FTP user password
```

### Viewing Credentials

```bash
cd inception/srcs/secrets
cat db_password.txt          # View database password
cat wp_admin_password.txt    # View WordPress admin password
```

### Changing Credentials

1. **Edit the secret file**:
   ```bash
   cd inception/srcs/secrets
   nano db_password.txt    # Edit the password
   ```

2. **Rebuild the affected service**:
   ```bash
   cd ..
   make down
   make up
   ```

⚠️ **Important**: For database passwords, you may need to reset the database:
```bash
make fclean
make
```

### Security Recommendations

- ✅ Use strong passwords (min. 12 characters, mixed case, numbers, symbols)
- ✅ Never commit secrets to git (already in `.gitignore`)
- ✅ Restrict file permissions: `chmod 600 secrets/*.txt`
- ✅ Change default passwords immediately after first deployment

---

## Verifying Service Health

### Quick Status Check

```bash
make ps
```

**Expected output**:
```
NAME        IMAGE       STATUS          PORTS
nginx       nginx       Up (healthy)    443/tcp
wordpress   wordpress   Up (healthy)    
mariadb     mariadb     Up (healthy)    
redis       redis       Up (healthy)    
...
```

### Detailed Health Check

```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
```

### Checking Logs

**All services**:
```bash
make logs
```

**Specific service**:
```bash
docker logs wordpress
docker logs mariadb
docker logs nginx
```

**Follow logs in real-time**:
```bash
docker logs -f wordpress
```

### Manual Service Tests

**Test NGINX**:
```bash
curl -k https://zobeiri.42.fr
```

**Test MariaDB** (from inside container):
```bash
docker exec -it mariadb mariadb -uroot -p
```

**Test WordPress**:
```bash
curl -k https://zobeiri.42.fr/wp-admin
```

**Test Redis**:
```bash
docker exec -it redis redis-cli
AUTH <redis_password>
PING    # Should return "PONG"
```

---

## Common Tasks

### Backing Up Data

**Backup WordPress files**:
```bash
docker run --rm -v wordpress_data:/data -v $(pwd):/backup alpine tar czf /backup/wordpress-backup.tar.gz /data
```

**Backup database**:
```bash
docker exec mariadb sh -c 'mariadb-dump -uroot -p"$(cat /run/secrets/wordpress_db_root_password)" wordpress' > backup.sql
```

### Restoring Data

**Restore WordPress files**:
```bash
docker run --rm -v wordpress_data:/data -v $(pwd):/backup alpine tar xzf /backup/wordpress-backup.tar.gz -C /
```

**Restore database**:
```bash
cat backup.sql | docker exec -i mariadb mariadb -uroot -p"$(cat srcs/secrets/db_root_password.txt)" wordpress
```

### Updating WordPress

WordPress can be updated through the admin panel or via command line:

```bash
docker exec -it wordpress wp core update --allow-root
docker exec -it wordpress wp plugin update --all --allow-root
```

### Managing Plugins

**Install a plugin**:
```bash
docker exec -it wordpress wp plugin install <plugin-name> --activate --allow-root
```

**List plugins**:
```bash
docker exec -it wordpress wp plugin list --allow-root
```

### Viewing Resource Usage

```bash
docker stats
```

---

## Troubleshooting

### Problem: Cannot access the website

**Check 1**: Verify containers are running
```bash
make ps
```

**Check 2**: Verify DNS/hosts configuration
```bash
ping zobeiri.42.fr
```

**Check 3**: Check NGINX logs
```bash
docker logs nginx
```

**Solution**: If containers are down, restart:
```bash
make down
make up
```

### Problem: Database connection error

**Check 1**: Verify MariaDB is healthy
```bash
docker ps | grep mariadb
```

**Check 2**: Check MariaDB logs
```bash
docker logs mariadb
```

**Check 3**: Verify credentials in secrets
```bash
cat srcs/secrets/db_password.txt
```

**Solution**: Reset the database
```bash
make fclean
make
```

### Problem: SSL certificate errors

**Check**: Verify certificate exists
```bash
docker exec nginx ls -la /etc/nginx/ssl/
```

**Solution**: Certificates are auto-generated. If missing:
```bash
make re
```

### Problem: FTP connection refused

**Check 1**: Verify FTP container is running
```bash
docker ps | grep ftp
```

**Check 2**: Check passive port range
```bash
docker logs ftp
```

**Solution**: Ensure ports 21000-21010 are open in your firewall

### Problem: Portainer won't start

**Check**: Verify Docker socket access
```bash
docker logs portainer
```

**Solution**: Ensure Docker socket is mounted:
```bash
docker inspect portainer | grep "/var/run/docker.sock"
```

### Getting Support

If issues persist:

1. **Collect logs**:
   ```bash
   make logs > debug.log
   ```

2. **Check service status**:
   ```bash
   docker ps -a > container_status.txt
   ```

3. **Verify configuration**:
   ```bash
   docker-compose config
   ```

---

For developer documentation and advanced configuration, see [DEV_DOC.md](DEV_DOC.md).