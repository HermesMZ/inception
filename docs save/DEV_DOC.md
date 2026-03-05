# Inception - Developer Documentation

This document provides technical information for developers working on the Inception project.

## Table of Contents

1. [Environment Setup](#environment-setup)
2. [Project Structure](#project-structure)
3. [Building and Deploying](#building-and-deploying)
4. [Container Management](#container-management)
5. [Data Persistence](#data-persistence)
6. [Service Configuration](#service-configuration)
7. [Development Workflow](#development-workflow)
8. [Debugging](#debugging)

---

## Environment Setup

### Infrastructure Deployment

The infrastructure deployment is fully automated through a sequence of three scripts. This approach ensures that the Virtual Machine (VM) environment is identical for every deployment and complies with the project's security requirements.

1. **System Preparation(1-install-vm.sh)**
	Executed as root. This script initializes the Debian VM software base:
	- Essential Packages: Installation of sudo, curl, git, make, and ufw.
	- Privileges: Primary user detection and addition to the sudo group.
	- SSH Security: Modification of the default port (22) to port 4242.
	- Firewall (UFW): Closing all incoming traffic except for port 4242 (SSH) and port 443 (HTTPS).

2. **Docker Installation(2-install-docker.sh)**
	Executed with sudo by the user. This script configures the container engine:
	- Official Repositories: Configuration of the GPG keyring and Docker APT sources.
	- Components: Installation of docker-ce and the docker-compose-plugin.
	- Permissions: Adding the user to the docker group to allow command execution without sudo.
	- Optimization: Docker daemon configuration (daemon.json) to limit log file size to 10MB.
	- Local DNS: Automatic registration of 127.0.0.1 $USER.42.fr in the /etc/hosts file.

3. **Project Configuration(3.setup-inception.sh)**
	Executed as a standard user. This script prepares the Inception workspace:
	- File Structure: Creation of the srcs/requirements/ hierarchy (MariaDB, NGINX, WordPress) along with configuration (conf/) and tools (tools/) directories.
	- Mount Points (Volumes): Physical creation of persistence directories on the host at /home/$USER/data/.
	- ID Management: Application of chown 100:101 on the MariaDB directory to ensure compatibility with the Alpine container's mysql user.
	- Templates: Automatic generation of the Makefile and a skeleton docker-compose.yml.

4. **Initial Configuration**
	- Clone the repository: 
	```bash
	git clone <repo_url> inception
	cd inception
	```
	- Copy and rename the environment file/
	```bash
	cp srcs/.env.example srcs/.env
	```
	Then edit it with your settings(domain name, users, etc.).
	- Generate secrets:
	```bash
	./scripts/secrets.sh
	```
	This creates password files in `srcs/secrets/` and sets proper permissions on .txt files.

### Project Structure

The file organization follows the standard hierarchy required by the subject:

```
/home/$USER/inception/
├── Makefile                # Lifecycle automation
├── scripts/                # Installation and secret generation scripts
└── srcs/
    ├── .env                # Global environment variables
    ├── docker-compose.yml  # Service orchestration
    └── requirements/       # Isolated configuration per service
        ├── mariadb/        # Dockerfile, my.cnf, init scripts
        ├── nginx/          # Dockerfile, SSL config, VHost
        └── wordpress/      # Dockerfile, PHP-FPM, WP-CLI
```

### Data Persistence & Volumes

	The project uses Docker named volumes with driver_opts pointing to /home/$USER/data:
	- MariaDB data → /var/lib/mysql → /home/$USER/data/mariadb
	- WordPress files → /var/www/html → /home/$USER/data/wordpress
	- Portainer data → /data → /home/$USER/data/portainer

	Benefits:
	- Data persists after container removal.
	- Files are visible on the host for inspection.
	- Docker manages volume lifecycle, ensuring portability.

	Inspecting volumes:
	```bash
	docker volume ls
	docker volume inspect mariadb_data
	```

### Secret Management

	All sensitive information (passwords, authentication keys) is stored using Docker secrets, mounted at /run/secrets/ inside the containers.
	- Passwords are not exposed as environment variables.
	- Generated dynamically by scripts/secrets.sh.
	- Automatically removed when the container stops.

	Example secrets:
	```
	/run/secrets/
	├── db_password
	├── db_root_password
	├── wordpress_admin_password
	├── redis_password
	└── ftp_password
	```
	Accessing secrets inside containers:
	``` bash
	cat /run/secrets/db_password
	```
	For security, secrets should not be committed to Git and should have strict file permissions (chmod 600).

<!--  -->

### Initial Configuration

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd inception
   ```

2. **Create environment file**:
   ```bash
   cd srcs
   cp .env.example .env
   ```

3. **Edit `.env` file**:
   ```bash
   nano .env
   ```

   **Required variables**:
   ```bash
   # Domain Configuration
   DOMAIN_NAME=$USER.42.fr
   
   # Database Configuration
   MYSQL_DATABASE=wordpress
   MYSQL_USER=wordpress
   
   # WordPress Configuration
   WP_TITLE="My Inception Site"
   WP_ADMIN_USER=admin
   WP_ADMIN_EMAIL=admin@example.com
   WP_URL=https://$USER.42.fr
   
   # Redis Configuration
   REDIS_HOST=redis
   
   # FTP Configuration
   FTP_USER=ftpuser
   ```

4. **Configure secrets**:
   ```bash
   cd secrets
   
   # Generate secure passwords
   openssl rand -base64 32 > db_password.txt
   openssl rand -base64 32 > db_root_password.txt
   openssl rand -base64 32 > redis_password.txt
   openssl rand -base64 32 > ftp_password.txt
   openssl rand -base64 32 > portainer_password.txt
   
   # Secure permissions
   chmod 600 *.txt
   ```

5. **Configure hosts file** (for local development):
   ```bash
   sudo nano /etc/hosts
   ```
   
   Add:
   ```
   127.0.0.1 $USER.42.fr
   ```

---

## Project Structure

```
inception/
├── Makefile                      # Build automation
├── README.md                     # Project overview
├── USER_DOC.md                   # User documentation
├── DEV_DOC.md                    # This file
└── srcs/
    ├── docker-compose.yml        # Service orchestration
    ├── .env                      # Environment variables
    ├── .env.example              # Environment template
    ├── secrets/                  # Docker secrets
    │   ├── db_password.txt
    │   ├── db_root_password.txt
    │   ├── redis_password.txt
    │   ├── ftp_password.txt
    │   └── portainer_password.txt
    ├── requirements/             # Mandatory services
    │   ├── mariadb/
    │   │   ├── Dockerfile
    │   │   ├── conf/
    │   │   │   └── my.cnf        # MariaDB configuration
    │   │   └── tools/
    │   │       └── init-db.sh    # Database initialization
    │   ├── nginx/
    │   │   ├── Dockerfile
    │   │   ├── conf/
    │   │   │   └── nginx.conf    # NGINX configuration
    │   │   └── tools/
    │   │       └── entrypoint.sh # SSL cert generation
    │   └── wordpress/
    │       ├── Dockerfile
    │       ├── conf/
    │       │   └── www.conf      # PHP-FPM configuration
    │       └── tools/
    │           └── init-wordpress.sh # WordPress setup
    └── bonus/                    # Additional services
        ├── adminer/
        ├── ftp/
        ├── portainer/
        ├── redis/
        └── static-site/
```

---

## Building and Deploying

### Makefile Commands

The project uses a Makefile for automation:

| Command | Description |
|---------|-------------|
| `make` or `make all` | Build and start all services |
| `make build` | Build all Docker images without starting |
| `make up` | Start containers (without building) |
| `make down` | Stop and remove containers |
| `make stop` | Stop containers without removing |
| `make start` | Start stopped containers |
| `make restart` | Restart all containers |
| `make re` | Rebuild everything from scratch |
| `make clean` | Remove containers and images |
| `make fclean` | Full cleanup including volumes |
| `make logs` | Show logs from all services |
| `make ps` | List container status |
| `make prune` | Remove unused Docker resources |

### Build Process

**Full build from scratch**:
```bash
make re
```

**Individual service build**:
```bash
docker compose -f srcs/docker-compose.yml build mariadb
docker compose -f srcs/docker-compose.yml build nginx
docker compose -f srcs/docker-compose.yml build wordpress
```

**Build with no cache** (force rebuild):
```bash
docker compose -f srcs/docker-compose.yml build --no-cache
```

### Deployment Steps

1. **Initial deployment**:
   ```bash
   make
   ```

2. **Verify all services are healthy**:
   ```bash
   make ps
   docker ps --format "table {{.Names}}\t{{.Status}}"
   ```

3. **Check logs for errors**:
   ```bash
   make logs
   ```

4. **Test connectivity**:
   ```bash
   curl -k https://$USER.42.fr
   ```

---

## Container Management

### Docker Compose Commands

All commands should be run from the `srcs/` directory:

```bash
cd srcs
```

**Start services**:
```bash
docker compose up -d
```

**Stop services**:
```bash
docker compose down
```

**View logs**:
```bash
docker compose logs -f [service_name]
```

**Execute commands in container**:
```bash
docker compose exec mariadb mariadb -uroot -p
docker compose exec wordpress wp --info --allow-root
docker compose exec nginx nginx -t
```

**Scale a service** (if stateless):
```bash
docker compose up -d --scale wordpress=3
```

### Container Inspection

**Inspect container configuration**:
```bash
docker inspect wordpress
```

**View container processes**:
```bash
docker top wordpress
```

**View resource usage**:
```bash
docker stats
```

**Access container filesystem**:
```bash
docker exec -it wordpress sh
```

### Network Management

**List networks**:
```bash
docker network ls
```

**Inspect the inception network**:
```bash
docker network inspect inception
```

**Test connectivity between containers**:
```bash
docker exec wordpress ping -c 3 mariadb
docker exec wordpress ping -c 3 redis
```

---

## Data Persistence

### Volume Types

The project uses two types of data persistence:

#### Docker Volumes (Managed by Docker)

| Volume Name | Purpose | Location |
|-------------|---------|----------|
| `wordpress_data` | WordPress files | `/var/lib/docker/volumes/` |
| `mariadb_data` | Database data | `/var/lib/docker/volumes/` |
| `portainer_data` | Portainer config | `/var/lib/docker/volumes/` |

**List volumes**:
```bash
docker volume ls
```

**Inspect a volume**:
```bash
docker volume inspect wordpress_data
```

**Backup a volume**:
```bash
docker run --rm \
  -v wordpress_data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/wordpress-$(date +%Y%m%d).tar.gz /data
```

**Restore a volume**:
```bash
docker run --rm \
  -v wordpress_data:/data \
  -v $(pwd):/backup \
  alpine tar xzf /backup/wordpress-20260304.tar.gz -C /
```

#### Bind Mounts (Direct host access)

| Path | Purpose | Container Mount |
|------|---------|-----------------|
| `./secrets/` | Docker secrets | `/run/secrets/` (read-only) |

**Access bind mount data**:
```bash
# Secrets
cat srcs/secrets/db_password.txt

# MariaDB logs (if configured)
tail -f /var/log/mysql/error.log
```

### Data Location

**On the host**:
```bash
# Docker volumes
ls -la /var/lib/docker/volumes/

# Container writable layers
ls -la /var/lib/docker/overlay2/
```

**Inside containers**:
```bash
# WordPress files
docker exec wordpress ls -la /var/www/html

# MariaDB data
docker exec mariadb ls -la /var/lib/mysql

# Secrets
docker exec wordpress ls -la /run/secrets
```

### Persistence Strategy

- ✅ **Database**: Stored in Docker volume (survives container recreation)
- ✅ **WordPress files**: Stored in Docker volume (plugins, themes, uploads persist)
- ✅ **Configuration**: Bind-mounted from host (easy to edit and version control)
- ✅ **Secrets**: Mounted as read-only files in `/run/secrets/`
- ✅ **Logs**: Can be configured to persist via volume or bind mount

---

## Service Configuration

### MariaDB

**Dockerfile**: `srcs/requirements/mariadb/Dockerfile`
**Init script**: `srcs/requirements/mariadb/tools/init-db.sh`
**Config**: `srcs/requirements/mariadb/conf/my.cnf`

**Key configuration options**:
```ini
[mysqld]
bind-address = 0.0.0.0          # Listen on all interfaces
skip-networking = 0              # Enable network connections
max_connections = 50             # Maximum concurrent connections
```

**Modifying configuration**:
1. Edit `my.cnf`
2. Rebuild: `docker compose build mariadb`
3. Restart: `docker compose up -d mariadb`

### NGINX

**Dockerfile**: `srcs/requirements/nginx/Dockerfile`
**Config**: `srcs/requirements/nginx/conf/nginx.conf`
**SSL setup**: `srcs/requirements/nginx/tools/entrypoint.sh`

**Key configuration**:
- TLS protocols: TLSv1.2, TLSv1.3
- Port: 443 (HTTPS only)
- Proxy to: `wordpress:9000` (FastCGI)

**Testing configuration**:
```bash
docker exec nginx nginx -t
```

**Reloading without downtime**:
```bash
docker exec nginx nginx -s reload
```

### WordPress

**Dockerfile**: `srcs/requirements/wordpress/Dockerfile`
**Init script**: `srcs/requirements/wordpress/tools/init-wordpress.sh`
**PHP-FPM config**: `srcs/requirements/wordpress/conf/www.conf`

**WP-CLI usage**:
```bash
# Install plugin
docker exec wordpress wp plugin install redis-cache --activate --allow-root

# Update WordPress
docker exec wordpress wp core update --allow-root

# Database operations
docker exec wordpress wp db export backup.sql --allow-root
```

### Redis

**Dockerfile**: `srcs/bonus/redis/Dockerfile`
**Init script**: `srcs/bonus/redis/tools/init-redis.sh`

**Testing Redis**:
```bash
docker exec redis redis-cli
AUTH <password_from_secret>
PING              # Should return PONG
KEYS *            # List cached keys
INFO stats        # View statistics
```

---

## Development Workflow

### Making Changes

1. **Edit configuration or Dockerfile**
2. **Rebuild the specific service**:
   ```bash
   docker compose build <service>
   ```
3. **Restart the service**:
   ```bash
   docker compose up -d <service>
   ```
4. **Verify changes**:
   ```bash
   docker compose logs -f <service>
   ```

### Adding a New Service

1. **Create service directory**:
   ```bash
   mkdir -p srcs/bonus/myservice
   cd srcs/bonus/myservice
   ```

2. **Create Dockerfile**:
   ```dockerfile
   FROM alpine:3.19
   
   RUN apk add --no-cache <packages>
   
   COPY tools/entrypoint.sh /
   RUN chmod +x /entrypoint.sh
   
   ENTRYPOINT ["/entrypoint.sh"]
   ```

3. **Add to docker-compose.yml**:
   ```yaml
   myservice:
     build: ./bonus/myservice
     image: myservice
     container_name: myservice
     restart: always
     networks:
       - inception
     depends_on:
       - mariadb
   ```

4. **Build and start**:
   ```bash
   docker compose build myservice
   docker compose up -d myservice
   ```

### Testing Changes

**Unit testing** (example for WordPress):
```bash
docker exec wordpress wp plugin list --allow-root
docker exec wordpress wp theme list --allow-root
```

**Integration testing**:
```bash
# Test database connectivity
docker exec wordpress wp db check --allow-root

# Test Redis connectivity
docker exec wordpress wp redis info --allow-root
```

**Performance testing**:
```bash
# Apache Bench
ab -n 1000 -c 10 https://$USER.42.fr/

# Monitor resource usage during test
docker stats
```

---

## Debugging

### Container Logs

**View all logs**:
```bash
make logs
```

**Follow specific service**:
```bash
docker logs -f --tail 100 wordpress
```

**View logs with timestamps**:
```bash
docker logs --timestamps mariadb
```

### Debugging a Failing Container

1. **Check if container started**:
   ```bash
   docker ps -a | grep <service>
   ```

2. **View build logs**:
   ```bash
   docker compose build <service>
   ```

3. **View container logs**:
   ```bash
   docker logs <container>
   ```

4. **Access shell for investigation**:
   ```bash
   docker exec -it <container> sh
   ```

5. **Override entrypoint for debugging**:
   ```bash
   docker run -it --entrypoint sh <image>
   ```

### Common Issues

**Issue**: Container exits immediately

**Debug**:
```bash
docker logs <container>
docker inspect <container>
```

**Solution**: Check entrypoint script has proper shebang and executable permissions

---

**Issue**: Cannot connect to MariaDB

**Debug**:
```bash
docker exec mariadb mariadb -uroot -p
docker exec wordpress ping mariadb
docker network inspect inception
```

**Solution**: Verify network configuration and healthcheck

---

**Issue**: Changes not reflected after rebuild

**Debug**:
```bash
docker compose build --no-cache <service>
docker system prune -a
```

**Solution**: Clear Docker cache

---

For user-facing documentation, see [USER_DOC.md](USER_DOC.md).
For project overview, see [README.md](README.md).

