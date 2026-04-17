# Inception - User Documentation

This document explains how to use the Inception infrastructure as an end user or system administrator.

## Table of Contents

1. [Services Overview](#services-overview)
2. [Starting and Stopping](#starting-and-stopping)
3. [Accessing Services](#accessing-services)
4. [Managing Credentials](#managing-credentials)
5. [Verifying Service Health](#verifying-service-health)

---

## Services Overview

The Inception infrastructure provides the following services:

- **NGINX** with TLSv1.2/TLSv1.3 as a reverse proxy
- **WordPress** with php-fpm
- **MariaDB** as the database system
- **Redis** cache for WordPress optimization
- **FTP Server** for file management
- **Adminer** for database administration
- **Static Website** Dashboard
- **Portainer** for Docker container management

---

## Starting and Stopping

### Prerequisites

Ensure you have:
- Docker Engine installed and running.
- Proper permissions to run Docker commands.
- The domain name configured in `/etc/hosts` (for local) or DNS (for production).
- Launched the script `/inception/scripts/secrects.sh`

### Starting the Infrastructure

`make`, `make all` or `make up`.


1. Build all Docker images (first time only).
2. Create necessary network.
3. Initialize services in the correct order.
4. Wait for all services to be healthy.

### Stopping the Infrastructure

**Graceful shutdown** (keeps data):

``
make down
``

1. Stop Services: Gracefully shut down all running containers.
2. Cleanup: Remove containers and internal networks.
3. Data Safety: Persistent data in /home/$USER/data is not deleted.

**Quick controls**

``
make stop
``
Stop containers without removing them.

``
make start
``
Start stopped containers.

``
make restart
``
Rebuild and restart with updates.

**Debugging & Monitoring**

``
make ps
``
Shows the real-time status, health, and port mapping of all stack components.


``
make logs
``
Live stream logs from all containers.


``
make tests
``
Launch security and accessibility tests. 

**Cleanup**:

``
make clean
``
Stops the project and removes all images and networks.

``
make fclean
``

1. Runs make clean.
2. Uses a temporary container to bypass permissions and delete all data in /home/$USER/data.
3. Prunes the Docker system cache.

⚠️ **Warning**: `make fclean` will delete all data including the database!

### Rebuilding
``
make re
``
Equivalent to make fclean followed by make all. Use this for a completely fresh deployment.

---

## Accessing Services

### Main Website (WordPress)

**URL**: `https://$USER.42.fr`

**Admin Panel**: `https://$USER.42.fr/wp-admin`

**Default credentials**:
- Username: WORDPRESS_ADMIN_USER or WORDPRESS_USER (set in the .env)
- Password: See secrets file (see [Managing Credentials](#managing-credentials))

### Database Management (Adminer)

**URL**: `https://$USER.42.fr/adminer`

**Login information**:
- System: `MySQL`
- Server: `mariadb`
- Username: `wordpress`
- Password: See `secrets/db_password.txt`
- Database: `wordpress`

**Connect to the Container**:
``
docker exec -it mariadb bash

``
``
mariadb -u mysqluser -p$(cat /run/secrets/db_password) --skip-ssl
``
``
SHOW DATABASES;
USE wordpress_db
SHOW TABLES
``

### Dashboard

**URL**: `https://$USER.42.fr/dashboard`

This is a static website, no authentication required.

### Container Management (Portainer)

**URL**: `https://$USER.42.fr/portainer`

**Login information**:
- Username: `admin`
- Password: See `secrets/portainer_password.txt`

### FTP Access

**Connection details**:
```
Host: $USER.42.fr
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
└── ftp_password.txt         # FTP user password
```

### Viewing Credentials

```bash
cd inception/srcs/secrets
cat db_password.txt          # View database password
cat wp_admin_password.txt    # View WordPress admin password
```

### Changing Credentials

Edit the proper file.

⚠️ **Important**: For database passwords, you may need to reset the database:
```bash
make re
```

### Security Recommendations

- ✅ Use strong passwords (min. 12 characters, mixed case, numbers, symbols).
- ✅ Never commit secrets to git (already in `.gitignore`).
- ✅ Restrict file permissions: `chmod 600 secrets/*.txt`.
- ✅ Change default passwords immediately after first deployment.

---

## Verifying Service Health

### Quick Status Check

```bash
make status
```

**Expected output**:
```
NAME        STATUS
adminer     Up 6 minutes (healthy)
dashboard   Up 6 minutes (healthy)
ftp         Up 6 minutes (healthy)
mariadb     Up 6 minutes (healthy)
nginx       Up 6 minutes (healthy)
portainer   Up 6 minutes (healthy)
redis       Up 6 minutes (healthy)
wordpress   Up 6 minutes (healthy)
```

### Detailed Health Check

```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
```

### Checking Logs

**All services in real-time**:
```bash
make logs
```

**Specific service**:
```bash
docker logs wordpress
```

**Follow logs in real-time**:
```bash
docker logs -f wordpress
```

---


For developer documentation and advanced configuration, see [DEV_DOC.md](DEV_DOC.md).