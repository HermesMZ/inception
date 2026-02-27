FROM alpine:3.22

RUN apk add --no-cache redis

# Copier la configuration Redis
COPY conf/redis.conf /etc/redis/redis.conf

# Copier le script de démarrage
COPY tools/init-redis.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/init-redis.sh

ENTRYPOINT ["/usr/local/bin/init-redis.sh"]