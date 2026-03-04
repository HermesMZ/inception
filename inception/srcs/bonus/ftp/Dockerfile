FROM alpine:3.22

# Installer vsftpd pour FTP
RUN apk update && apk add --no-cache \
    vsftpd \
    netcat-openbsd \
	bash

# Créer le répertoire pour l'utilisateur FTP
RUN mkdir -p /home/ftpuser/wordpress && \
    adduser -D -h /home/ftpuser ftpuser && \
    chown -R ftpuser:ftpuser /home/ftpuser

# Copier la configuration vsftpd
COPY conf/vsftpd.conf /etc/vsftpd/vsftpd.conf

# Copier le script d'initialisation
COPY tools/init-ftp.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/init-ftp.sh

# Port FTP contrôle et ports passifs
EXPOSE 21 21000-21010

ENTRYPOINT ["/usr/local/bin/init-ftp.sh"]
