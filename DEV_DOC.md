# Inception - Developer Documentation

This document provides technical information for developers working on the Inception project.

## Table of Contents

1. [Environment Setup](#environment-setup)
2. [Project Structure](#project-structure)
3. [Building and Deploying](#building-and-deploying)
4. [Container Management](#container-management)
5. [Data Persistence](#data-persistence)
6. [Bonus Services](#bonus-services)

---

## Environment Setup

### Infrastructure Deployment

The infrastructure deployment is fully automated through a sequence of three scripts. This approach ensures that the Virtual Machine (VM) environment is identical for every deployment and complies with the project's security requirements.

0. **Copy installation scripts to the VM**

From the host machine, copy the installation scripts to the virtual machine:
```bash
scp 1-install-vm.sh user@IP_VM:/home/user/
scp 2-install-docker.sh user@IP_VM:/home/user/
scp 3-setup-docker.sh user@IP_VM:/home/user/
```
Then connect to the VM and switch to the root user:
```bash
su -
```
Run the first script to initialize the system.

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
├── Makefile                     # Lifecycle automation
├── scripts/                     # Installation and setup scripts
│   ├── 1-install-vm.sh          # VM preparation (root)
│   ├── 2-install-docker.sh      # Docker installation (sudo)
│   ├── 3-setup-inception.sh     # Project setup (user)
│   ├── secrets.sh               # Generate all secrets
│   ├── check_volumes.sh         # Verify volume mounts
│   └── test-inception.sh        # Run test suite
└── srcs/
    ├── .env                     # Global environment variables
    ├── docker-compose.yml       # Service orchestration
    ├── requirements/            # Mandatory services
    │   ├── mariadb/             # Database service
    │   │   ├── Dockerfile
    │   │   ├── conf/            # MariaDB configuration
    │   │   │   └── mariadb.cnf
    │   │   └── tools/
    │   │       └── init-db.sh   # Database initialization
    │   ├── nginx/               # Web server & reverse proxy
    │   │   ├── Dockerfile
    │   │   └── conf/
    │   │       └── nginx.conf   # SSL, virtual hosts
    │   └── wordpress/           # CMS with PHP-FPM
    │       ├── Dockerfile
    │       ├── conf/
    │       │   └── www.conf     # PHP-FPM pool config
    │       └── tools/
    │           └── init-wordpress.sh
    ├── bonus/                   # Additional services
    │   ├── adminer/             # Database management UI
    │   │   └── Dockerfile
    │   ├── redis/               # Cache system
    │   │   ├── Dockerfile
    │   │   ├── conf/redis.conf
    │   │   └── tools/init-redis.sh
    │   ├── ftp/                 # FTP server (vsftpd)
    │   │   ├── Dockerfile
    │   │   ├── conf/vsftpd.conf
    │   │   └── tools/init-ftp.sh
    │   ├── portainer/           # Container management UI
    │   │   ├── Dockerfile
    │   │   └── tools/init-portainer.sh
    │   └── dashboard/           # Static dashboard
    │       ├── Dockerfile
    │       ├── conf/nginx.conf
    │       └── site/index.html
    └── secrets/                 # Docker secrets (gitignored)
        ├── db_password.txt
        ├── db_root_password.txt
        ├── ftp_password.txt
        ├── portainer_password.txt
        ├── redis_password.txt
        └── wp_*.txt             # WordPress salts and keys
```

**Key Differences:**

- **requirements/**: Mandatory services (NGINX, WordPress, MariaDB) as per project subject
- **bonus/**: Additional services (Adminer, Redis, FTP, Portainer, Dashboard)
- Each service is self-contained with its Dockerfile and configuration files

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

---

## Building and Deploying

### Dockerfile Structure

All services use **Alpine Linux** as the base image for minimal footprint and security. Each Dockerfile follows this pattern:

1. **Base Image**: Alpine Linux (3.22)
2. **Package Installation**: Only necessary runtime dependencies
3. **Configuration**: Copy config files and set permissions
4. **User Creation**: Non-root user for security
5. **Entrypoint**: Init script to handle startup logic

**Example from MariaDB Dockerfile:**
```dockerfile
FROM alpine:3.22
RUN apk add --no-cache mariadb mariadb-client
COPY conf/mariadb.cnf /etc/my.cnf.d/
COPY tools/init-db.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/init-db.sh
USER mysql
ENTRYPOINT ["init-db.sh"]
```

### Docker Compose Orchestration

The `docker-compose.yml` defines:
- **Services**: Each container with build context and configuration
- **Networks**: Custom bridge network `inception` for inter-service communication
- **Volumes**: Named volumes with bind mount backing to `/home/$USER/data`
- **Secrets**: File-based secrets mounted read-only
- **Dependencies**: Service startup order with health checks

**Service Dependency Chain:**
```
mariadb (healthcheck: mysqladmin ping)
  ↓
wordpress (depends_on: mariadb, redis)
  ↓
nginx (depends_on: wordpress)
```

**Key Compose Features Used:**
- `depends_on` with `condition: service_healthy`
- `restart: unless-stopped` for resilience
- `healthcheck` for all services
- `secrets` instead of environment variables for sensitive data

### Makefile Commands

The Makefile automates the entire lifecycle:

| Command | Description | Docker Equivalent |
|---------|-------------|-------------------|
| `make` / `make all` | Build and start all services | `docker compose up -d --build` |
| `make build` | Build images without starting | `docker compose build` |
| `make up` | Start containers | `docker compose up -d` |
| `make down` | Stop and remove containers | `docker compose down` |
| `make stop` | Stop without removing | `docker compose stop` |
| `make start` | Start stopped containers | `docker compose start` |
| `make restart` | Restart with updates | `down` + `build` + `up` |
| `make re` | Full rebuild | `fclean` + `all` |
| `make clean` | Remove containers + images | `down` + `rmi` |
| `make fclean` | Clean + delete volumes | `clean` + `rm -rf /home/$USER/data` |
| `make logs` | Show all logs | `docker compose logs -f` |
| `make ps` | List running containers | `docker compose ps` |

**Important Notes:**
- `make re` is useful for testing infrastructure changes
- `make fclean` deletes all data - use with caution
- Secrets must be generated before first `make`

### Service Launch Order

The `depends_on` configuration ensures proper startup sequence:

1. **MariaDB** starts first
   - Healthcheck: `mysqladmin ping -h localhost`
   - Must be healthy before WordPress starts

2. **Redis** starts in parallel with MariaDB
   - Healthcheck: `redis-cli ping`

3. **WordPress** waits for MariaDB and Redis
   - Healthcheck: `curl -f http://localhost:9000/wp-admin/install.php`
   - Installs WordPress if not already present
   - Configures Redis cache

4. **NGINX** waits for WordPress
   - Healthcheck: `curl -f https://localhost:443`
   - Serves WordPress via FastCGI

5. **Bonus services** start independently
   - Adminer, FTP, Portainer, Dashboard

Healthchecks prevent cascading failures and ensure services are truly ready before dependent services start.

---

## Container Management

### Volumes Management

**Named Volumes with Bind Mounts:**

The project uses Docker named volumes pointing to physical directories:

```yaml
volumes:
  mariadb_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/${USER}/data/mariadb
```

**Volume Inspection:**
```bash
# List all volumes
docker volume ls

# Inspect volume details
docker volume inspect mariadb_data

# Check physical location
ls -la /home/$USER/data/mariadb
```

### Healthchecks

Every service has a healthcheck to verify it's operational. These healthchecks are essential for the `depends_on` configuration, ensuring that dependent services only start once their dependencies are truly ready and healthy, preventing cascading failures during startup.

**Example healthcheck configurations:**
```yaml
# MariaDB
healthcheck:
  test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
  interval: 10s
  timeout: 5s
  retries: 5

# WordPress
healthcheck:
  test: ["CMD-SHELL", "curl -f http://localhost:9000/wp-admin/install.php || exit 1"]
  interval: 10s
  timeout: 5s
  retries: 5
```

### Secrets Mounting

Secrets are mounted as read-only files:

```yaml
services:
  mariadb:
    secrets:
      - db_root_password
      - db_password

secrets:
  db_root_password:
    file: ./secrets/db_root_password.txt
  db_password:
    file: ./secrets/db_password.txt
```

**Inside containers:**
```bash
docker exec mariadb cat /run/secrets/db_root_password
```

Secrets are automatically removed when the container stops.

---

## Data Persistence

### Volume Structure

Data that must persist across container restarts:

| Service | Container Path | Host Path | Content |
|---------|---------------|-----------|---------|
| MariaDB | `/var/lib/mysql` | `/home/$USER/data/mariadb` | Database files |
| WordPress | `/var/www/html` | `/home/$USER/data/wordpress` | WP core, themes, plugins, uploads |
| Portainer | `/data` | `/home/$USER/data/portainer` | Portainer configuration |

### Host Storage Layout

```
/home/$USER/data/
├── mariadb/
│   ├── mysql/              # System database
│   ├── wordpress/          # Application database
│   └── performance_schema/
├── wordpress/
│   ├── wp-content/
│   │   ├── themes/
│   │   ├── plugins/
│   │   └── uploads/
│   ├── wp-config.php
│   └── [WordPress core files]
└── portainer/
    └── portainer.db
```

---

## Bonus Services

Bonus services (Adminer, Redis, FTP, Portainer, Dashboard) are included to extend the functionality of the infrastructure. Each runs in its own isolated container and integrates seamlessly into the main Docker network (`inception`). 

All bonus service configurations—ports, volumes, environment variables, and dependencies—are defined in the `docker-compose.yml` file. Specific configuration files (e.g., `redis.conf`, `vsftpd.conf`) are located in their respective `bonus/<service>/conf/` directories.

---

*For user instructions, see [USER_DOC.md](USER_DOC.md)*  
*For project overview, see [README.md](README.md)*