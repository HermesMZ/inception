FROM alpine:3.22

RUN apk update && apk add --no-cache \
    vsftpd \
    netcat-openbsd \
    libcap \
    linux-pam \
    bash

# Création de l'utilisateur avec un shell valide
RUN adduser -D -s /bin/bash -h /home/ftpuser ftpuser && \
    mkdir -p /home/ftpuser/wordpress && \
    mkdir -p /var/log && \
    touch /var/log/vsftpd.log && \
    chown ftpuser:ftpuser /var/log/vsftpd.log && \
    chown -R ftpuser:ftpuser /home/ftpuser

# Capabilities réseau
RUN setcap 'cap_net_bind_service=+ep' /usr/sbin/vsftpd

# Configuration PAM
RUN mkdir -p /etc/pam.d && \
    echo "auth required pam_unix.so" > /etc/pam.d/vsftpd && \
    echo "account required pam_unix.so" >> /etc/pam.d/vsftpd

# Dossier vsftpd
RUN mkdir -p /var/run/vsftpd/empty && \
    chmod 555 /var/run/vsftpd/empty

COPY conf/vsftpd.conf /etc/vsftpd/vsftpd.conf
COPY tools/init-ftp.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/init-ftp.sh

EXPOSE 21 21000-21010

ENTRYPOINT ["/usr/local/bin/init-ftp.sh"]