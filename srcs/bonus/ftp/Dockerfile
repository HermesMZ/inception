FROM alpine:3.22

# Installer vsftpd et les outils nécessaires
RUN apk update && apk add --no-cache \
    vsftpd \
    netcat-openbsd \
    libcap \
    bash

# Donner les capacités nécessaires au binaire vsftpd
RUN setcap 'cap_net_bind_service=+ep' /usr/sbin/vsftpd

# Créer le répertoire pour l'utilisateur FTP et le répertoire de logs
RUN mkdir -p /home/ftpuser/wordpress && \
    mkdir -p /var/log && \
    adduser -D -h /home/ftpuser ftpuser && \
    chown -R ftpuser:ftpuser /home/ftpuser

# Copier la configuration vsftpd et le script d'initialisation
COPY conf/vsftpd.conf /etc/vsftpd/vsftpd.conf
COPY tools/init-ftp.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/init-ftp.sh

# Créer le répertoire chroot vide requis par vsftpd
RUN mkdir -p /var/run/vsftpd/empty && \
    chown root:root /var/run/vsftpd/empty && \
    chmod 555 /var/run/vsftpd/empty

# Exposer les ports FTP
EXPOSE 21 21000-21010

ENTRYPOINT ["/bin/bash", "/usr/local/bin/init-ftp.sh"]
