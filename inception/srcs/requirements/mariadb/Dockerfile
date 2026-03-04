FROM alpine:3.22

# Créer user mysql avec UID=1000
RUN adduser -D -u 1000 mysqluser

# Installer MariaDB et bash
RUN apk update && \
    apk add --no-cache mariadb mariadb-client bash

# Création des dossiers nécessaires avec bons droits
RUN mkdir -p /run/mysqld /var/lib/mysql && \
    chown -R mysqluser:mysqluser /run/mysqld /var/lib/mysql

# Désactiver skip-networking dans le fichier par défaut
RUN sed -i 's/^skip-networking/#skip-networking/' /etc/my.cnf.d/mariadb-server.cnf

# Copier la configuration MariaDB
COPY conf/mariadb.cnf /etc/my.cnf.d/mariadb.cnf

# Copier le script d'initialisation
COPY tools/init-db.sh /usr/local/bin/init-db.sh
RUN chmod +x /usr/local/bin/init-db.sh

ENTRYPOINT ["/usr/local/bin/init-db.sh"]
