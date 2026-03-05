FROM alpine:3.22

RUN apk update && apk add --no-cache nginx

RUN mkdir -p /var/www/html

COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY site/index.html /var/www/html/index.html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]