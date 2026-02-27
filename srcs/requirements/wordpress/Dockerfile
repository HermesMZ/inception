# Utiliser Alpine 3.22
FROM alpine:3.22

# Installer PHP, extensions MySQL et utilitaires
RUN apk update && apk add --no-cache \
	php \
    php-fpm \
    php-mysqli \
    php-curl \
    php-openssl \
    php-ctype \
    php-json \
    php-mbstring \
    php-xml \
    php-phar \
	mariadb-client \
    fcgi \
    netcat-openbsd \
    curl \
    less

# Installer WP-CLI
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp

# Créer l'utilisateur et le groupe www-data si nécessaire
RUN getent group www-data || addgroup -S www-data && \
    getent passwd www-data || adduser -S -G www-data -h /var/www -s /sbin/nologin www-data

# Créer le dossier web et donner les droits à www-data
RUN mkdir -p /var/www/html && \
    chown -R www-data:www-data /var/www/html

# Copier le script d'init
COPY tools/init-wordpress.sh /usr/local/bin/init-wordpress.sh
RUN chmod +x /usr/local/bin/init-wordpress.sh
COPY conf/www.conf /etc/php83/php-fpm.d/www.conf

# Exposer le port PHP-FPM
EXPOSE 9000

RUN mkdir -p /var/log/php83 && \
	touch /var/log/php83/error.log && \
	chown -R root:www-data /var/log/php83 && \
	chmod -R 775 /var/log/php83

# Lancer le script en tant que root pour gérer les permissions
ENTRYPOINT [ "/usr/local/bin/init-wordpress.sh" ]
