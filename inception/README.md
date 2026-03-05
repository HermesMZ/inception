# Inception

*This project has been created as part of the 42 curriculum by zobeiri.*

## Description

Inception is a System Administration project that focuses on containerization using Docker. The goal is to set up a complete web infrastructure using Docker Compose, with each service running in its own dedicated container.

The project implements a multi-service architecture featuring:
- **NGINX** with TLSv1.2/TLSv1.3 as a reverse proxy
- **WordPress** with php-fpm
- **MariaDB** as the database system
- **Redis** cache for WordPress optimization
- **FTP Server** for file management
- **Adminer** for database administration
- **Static Website** showcasing personal CV
- **Portainer** for Docker container management

All services are orchestrated using Docker Compose and communicate through a custom Docker network. Sensitive data is managed using Docker secrets instead of environment variables.

## Instructions

### Prerequisites
- Docker Engine (20.10+)
- Docker Compose (2.0+)
- Make
- A domain name pointing to your server (for production) or hosts file configuration (for local development)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd inception
   ```

2. **Configure the environment**
   ```bash
   cd inception/srcs
   cp .env.example .env
   # Edit .env with your domain and configuration
   ```

3. **Set up secrets**
   ```bash
   cd secrets
   # Edit each .txt file with your passwords
   # Ensure proper permissions (600)
   chmod 600 *.txt
   ```

4. **Build and start the infrastructure**
   ```bash
   make
   ```

### Available Make commands

- `make` or `make all` - Build and start all services
- `make build` - Build all Docker images
- `make up` - Start all containers
- `make down` - Stop all containers
- `make stop` - Stop containers without removing them
- `make start` - Start stopped containers
- `make re` - Rebuild everything from scratch
- `make clean` - Remove containers and images
- `make fclean` - Full cleanup including volumes
- `make logs` - Show logs from all services
- `make ps` - List running containers

### Accessing the services

After starting the project:
- **WordPress**: https://zobeiri.42.fr
- **Adminer**: https://zobeiri.42.fr/adminer
- **Static Site**: https://zobeiri.42.fr/cv
- **Portainer**: https://zobeiri.42.fr:9443
- **FTP**: ftp://zobeiri.42.fr:21

## Resources

### Official Documentation
- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)
- [Docker Secrets](https://docs.docker.com/engine/swarm/secrets/)
- [NGINX Documentation](https://nginx.org/en/docs/)
- [WordPress Docker Images](https://hub.docker.com/_/wordpress)
- [MariaDB Documentation](https://mariadb.org/documentation/)

### Tutorials & Articles
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Alpine Linux Docker Images](https://hub.docker.com/_/alpine)
- [TLS/SSL Configuration](https://ssl-config.mozilla.org/)

### AI Usage

AI (GitHub Copilot with Claude Sonnet 4.5) was used for the following tasks:
- **Debugging**: Troubleshooting container connection issues and healthcheck configurations
- **Script optimization**: Improving shell scripts for secret management and service initialization
- **Documentation**: Generating initial structure for README and documentation files
- **Configuration review**: Validating Docker Compose and Dockerfile configurations
- **Best practices**: Suggesting security improvements and Docker optimization techniques

The core architecture, service selection, and implementation decisions were made independently.

## Project Description

### Docker Architecture

This project uses **Docker** to containerize each service independently, ensuring:
- **Isolation**: Each service runs in its own container
- **Reproducibility**: Consistent behavior across environments
- **Scalability**: Easy to add or remove services
- **Portability**: Can be deployed anywhere Docker runs

### Sources Organization

```
inception/
├── srcs/
│   ├── requirements/         # Mandatory services
│   │   ├── mariadb/         # Database service
│   │   ├── nginx/           # Web server & reverse proxy
│   │   └── wordpress/       # CMS with PHP-FPM
│   ├── bonus/               # Additional services
│   │   ├── adminer/         # Database management
│   │   ├── ftp/             # FTP server
│   │   ├── portainer/       # Container management UI
│   │   ├── redis/           # Cache system
│   │   └── static-site/     # Personal CV website
│   ├── secrets/             # Docker secrets files
│   ├── docker-compose.yml   # Service orchestration
│   ├── .env                 # Environment configuration
│   └── Makefile            # Build automation
```

### Technical Choices

#### Virtual Machines vs Docker

| Aspect | Virtual Machines | Docker |
|--------|-----------------|--------|
| **Resource Usage** | Heavy (full OS per VM) | Light (shared kernel) |
| **Startup Time** | Minutes | Seconds |
| **Isolation** | Complete (hypervisor) | Process-level |
| **Portability** | Limited (hypervisor-dependent) | High (runs anywhere) |
| **Use Case** | Full OS simulation | Service containerization |

**Choice for this project**: Docker
- ✅ Faster deployment and iteration
- ✅ Lower resource consumption
- ✅ Better suited for microservices architecture
- ✅ Easier to version control (Dockerfiles)

#### Secrets vs Environment Variables

| Aspect | Environment Variables | Docker Secrets |
|--------|----------------------|----------------|
| **Security** | Visible in `docker inspect` | Encrypted, tmpfs only |
| **Visibility** | Stored in container config | Only accessible in container |
| **Version Control** | Risk of committing sensitive data | Files excluded from git |
| **Management** | Scattered in docker-compose | Centralized in `/run/secrets` |

**Choice for this project**: Docker Secrets
- ✅ More secure (not exposed in environment)
- ✅ Not visible in container metadata
- ✅ Mounted in memory (tmpfs), never written to disk
- ✅ Centralized management

#### Docker Network vs Host Network

| Aspect | Docker Network | Host Network |
|--------|---------------|--------------|
| **Isolation** | Complete network isolation | Shares host network stack |
| **Port Mapping** | Manual mapping required | Direct access to all ports |
| **DNS Resolution** | Built-in service discovery | Must use host DNS |
| **Security** | Container-to-container only | Direct access to host |

**Choice for this project**: Docker Network (bridge mode)
- ✅ Better security (isolated network)
- ✅ Service discovery by container name
- ✅ Controlled port exposure
- ✅ Easier to manage inter-service communication

#### Docker Volumes vs Bind Mounts

| Aspect | Docker Volumes | Bind Mounts |
|--------|---------------|-------------|
| **Management** | Docker manages location | User specifies exact path |
| **Portability** | Portable across systems | Path-dependent |
| **Performance** | Optimized by Docker | Direct filesystem access |
| **Backup** | Docker CLI commands | Standard filesystem tools |

**Choice for this project**: Both, depending on use case

**Docker Volumes** for:
- ✅ WordPress files (`wordpress_data`)
- ✅ MariaDB data (`mariadb_data`)
- ✅ Portainer data (`portainer_data`)
- ✅ Better isolation and Docker-managed lifecycle

**Bind Mounts** for:
- ✅ Configuration files (nginx.conf, php.ini)
- ✅ Development: easier access to logs and configs
- ✅ Secrets directory (read-only access)

### Design Decisions

1. **Alpine Linux base images**: Minimal footprint, security-focused
2. **Multi-stage builds**: Reduced final image size where applicable
3. **Non-root users**: Each service runs with dedicated unprivileged user
4. **Healthchecks**: Automated service availability monitoring
5. **TLS everywhere**: All HTTP traffic encrypted with TLSv1.2/1.3
6. **Dependency management**: Using `depends_on` with healthcheck conditions
7. **Read-only secrets**: Secrets mounted with read-only permissions

---

*For detailed user instructions, see [USER_DOC.md](USER_DOC.md)*  
*For developer documentation, see [DEV_DOC.md](DEV_DOC.md)*