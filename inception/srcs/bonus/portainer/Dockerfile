FROM alpine:3.22

RUN apk add --no-cache wget tar ca-certificates curl shadow su-exec bash && \
    update-ca-certificates && \
    wget -O /tmp/portainer.tar.gz \
        https://github.com/portainer/portainer/releases/download/2.39.0/portainer-2.39.0-linux-amd64.tar.gz && \
    mkdir -p /opt/portainer && \
    tar --strip-components=1 -xzf /tmp/portainer.tar.gz -C /opt/portainer && \
    rm /tmp/portainer.tar.gz

RUN addgroup -g 1000 portainer && \
    adduser -D -u 1000 -G portainer portainer && \
    mkdir -p /data && \
    chown -R portainer:portainer /data /opt/portainer

COPY --chmod=755 tools/init-portainer.sh /usr/local/bin/init-portainer.sh

# On RESTE en root pour que l'entrypoint puisse modifier les groupes
USER root

EXPOSE 9000
ENTRYPOINT ["/usr/local/bin/init-portainer.sh"]