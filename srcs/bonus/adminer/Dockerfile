FROM alpine:3.22

# Installer PHP 8.3 CLI et extensions
RUN apk update && apk add --no-cache \
    php83 \
    php83-mysqli \
    php83-session \
    php83-json \
    netcat-openbsd \
    curl

# Télécharger Adminer
RUN mkdir -p /var/www/html && \
    curl -L https://github.com/vrana/adminer/releases/download/v4.8.1/adminer-4.8.1.php \
         -o /var/www/html/index.php && \
    chown -R nobody:nobody /var/www/html

# Pour info 
WORKDIR /var/www/html
EXPOSE 8080

# Utilisateur standard sans privilèges.
USER nobody

# Serveur web intégré PHP
CMD ["php83", "-S", "0.0.0.0:8080", "-t", "/var/www/html"]