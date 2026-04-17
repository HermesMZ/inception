# Inception

*This project has been created as part of the 42 curriculum by mzimeris.*

## Description

Inception is a System Administration project that focuses on containerization using Docker. The goal is to set up a complete web infrastructure using Docker Compose, with each service running in its own dedicated container.

The project implements a multi-service architecture featuring:
- **NGINX** with TLSv1.2/TLSv1.3 as a reverse proxy
- **WordPress** with php-fpm
- **MariaDB** as the database system
- **Redis** cache for WordPress optimization
- **FTP Server** for file management
- **Adminer** for database administration
- **Static Website** Dashboard
- **Portainer** for Docker container management

All services are orchestrated using Docker Compose and communicate through a custom Docker network. Sensitive data is managed using Docker secrets instead of environment variables.

## Instructions

### Prerequisites
- Virtual Machine Debian 12 (bookworm)

### Installation

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
cd scripts
./secrets.sh
```
This creates password files in `srcs/secrets/` and sets proper permissions on .txt files.

### Available Make commands

- `make` or `make all` - Build and start all services
- `make build` - Build all Docker images
- `make up` - Start all containers
- `make down` - Stop all containers
- `make stop` - Stop containers without removing them
- `make start` - Start stopped containers
- `make restart` - Rebuild and restart with updates
- `make re` - Rebuild everything from scratch
- `make clean` - Remove containers and images
- `make fclean` - Full cleanup including volumes
- `make logs` - Show logs from all services
- `make ps` - List running containers
- `make test` - Tests des containers

### Accessing the services

After starting the project:
- **WordPress**: https://$USER.42.fr
- **Adminer**: https://$USER.42.fr/adminer
- **Static Site**: https://$USER.42.fr/static
- **Portainer**: https://$USER.42.fr/portainer
- **FTP**: ftp://$USER.42.fr

## Resources

### Official Documentation
- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)
- [Docker Secrets](https://docs.docker.com/engine/swarm/secrets/)
- [NGINX Documentation](https://nginx.org/en/docs/)
- [WordPress Docker Images](https://hub.docker.com/_/wordpress)
- [MariaDB Documentation](https://mariadb.org/documentation/)
- [Portainer Documentation](https://portainer-notes.readthedocs.io/en/latest/)
- [Redis Documentation](https://redis.io/docs/latest/operate/oss_and_stack/)
- [Adminer official](https://www.adminer.org/)

### Tutorials & Articles
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Alpine Linux Docker Images](https://hub.docker.com/_/alpine)
- [TLS/SSL Configuration](https://ssl-config.mozilla.org/)
- [Blog Stéphane Robert](https://blog.stephane-robert.info/)

### AI Usage

AI (GitHub Copilot with Claude Sonnet 4.5) was used for the following tasks:
- **Debugging**: Troubleshooting container connection issues and healthcheck configurations
- **Script optimization**: Improving shell scripts for secret management and service initialization
- **Configuration review**: Validating Docker Compose and Dockerfile configurations
- **Best practices**: Suggesting security improvements and Docker optimization techniques

The core architecture, service selection, and implementation decisions were made independently.

## Project Description

### Why Docker?

This project uses **Docker** to containerize each service independently, ensuring:
- **Isolation**: Each service runs in its own container
- **Reproducibility**: Consistent behavior across environments
- **Scalability**: Easy to add or remove services
- **Portability**: Can be deployed anywhere Docker runs

### Project Structure

The file organization follows a clear separation between mandatory and bonus services:

```
inception/
├── srcs/
│   ├── requirements/       # Mandatory services
│   │   ├── mariadb/		# Database service
│   │   ├── nginx/          # Web server & reverse proxy
│   │   └── wordpress/      # CMS with PHP-FPM
│   ├── bonus/              # Additional services
│   │   ├── adminer/        # Database management
│   │   ├── ftp/            # FTP server
│   │   ├── portainer/		# Container management UI
│   │   ├── redis/         	# Cache system
│   │   └── dashboard/     	# Dashboard
│   ├── secrets/            # Docker secrets files
│   ├── docker-compose.yml  # Service orchestration
│   ├── .env                # Environment configuration
│   ├── Makefile            # Build automation
│   └──	Scripts/			# Different Shell scripts for setup and tests
```

**Key Directories:**
- **`requirements/`**: Mandatory services (NGINX, WordPress, MariaDB)
- **`bonus/`**: Additional services for extra credit
- **`secrets/`**: Docker secrets (not committed to git)
- **`scripts/`**: Automation scripts for setup and testing

### Technical Choices

#### Virtual Machines vs Docker

Virtual machines and Docker containers both allow applications to run in isolated environments, but they work very differently.

A virtual machine runs a complete operating system on top of a hypervisor. This provides strong isolation but requires significant resources because each VM includes its own OS. As a result, virtual machines consume more memory and disk space, and they usually take several minutes to start.

Docker containers are much lighter because they share the host system’s kernel. Instead of running a full operating system, they only include the application and its dependencies. This makes containers faster to start and more efficient in terms of resource usage.

For this project, Docker was chosen because it is better suited for running multiple services together. Containers start quickly, consume fewer resources, and make it easier to manage and version the infrastructure using Dockerfiles.

**Choice for this project**: Docker
- ✅ Faster deployment and iteration
- ✅ Lower resource consumption
- ✅ Better suited for microservices architecture
- ✅ Easier to version control (Dockerfiles)

#### Secrets vs Environment Variables

Sensitive information such as passwords can be provided to containers in different ways. The most common approach is to use environment variables. While this method is simple, it has some security limitations. Environment variables can be visible through commands such as docker inspect, which means sensitive data may be exposed in container metadata.

Docker Secrets provide a more secure alternative. Instead of being stored as environment variables, secrets are mounted inside the container as files when the container starts. They are typically available in the /run/secrets directory and can only be accessed from inside the container.

In this project, the secrets correspond to files stored on the host system and mounted read-only inside the containers. This prevents them from appearing in container metadata and keeps sensitive data separate from the application configuration.

**Choice for this project**: Docker Secrets
- ✅ More secure (not exposed in environment)
- ✅ Not visible in container metadata
- ✅ Centralized management

#### Docker Network vs Host Network

Containers need a way to communicate with each other and with the outside world. Docker offers several networking modes, including bridge networks and host networking.

When using the host network mode, containers share the same network stack as the host machine. This allows direct access to host ports but reduces isolation and can introduce security risks.

A Docker bridge network provides a separate internal network for containers. Each container receives its own IP address, and Docker provides automatic DNS resolution so that services can communicate with each other using container names.

For this project, a Docker bridge network is used. This allows services such as NGINX, WordPress, and MariaDB to communicate internally while limiting the exposure of ports to the host system.

**Choice for this project**: Docker Network (bridge mode)
- ✅ Better security (isolated network)
- ✅ Service discovery by container name
- ✅ Controlled port exposure
- ✅ Easier to manage inter-service communication

#### Docker Volumes vs Bind Mounts

Containers are ephemeral by design, which means that data stored inside them disappears when the container is removed. To persist data, Docker provides volumes and bind mounts.

Docker volumes are managed entirely by Docker. They are stored in a location controlled by the Docker engine and are designed specifically for persistent container data. Volumes are generally easier to manage and safer to use for application data.

Bind mounts, on the other hand, directly connect a directory from the host filesystem to a directory inside the container. This makes it easy to access or modify files from the host system, but it also creates a stronger dependency on the host environment.

In this project, both approaches are used depending on the situation. Docker volumes are used for persistent service data such as WordPress files, MariaDB databases, and Portainer data. Bind mounts are used for configuration files and the secrets directory, since these files may need to be edited directly from the host system.

**Choice for this project**: In this project, we use Named Volumes with Bind Mount backing. This allows us to benefit from Docker's volume management while ensuring the data is physically stored in the mandatory /home/$USER/data directory for evaluation purposes.

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