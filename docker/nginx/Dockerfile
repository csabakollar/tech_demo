FROM alpine:3.3
MAINTAINER Csaba Kollar <csaba.kollar@gmail.com>

ENV NGINX_VERSION nginx-1.9.6
RUN apk --update add openssl-dev pcre-dev zlib-dev wget build-base && \
    mkdir -p /tmp/src && \
    cd /tmp/src && \
    wget http://nginx.org/download/${NGINX_VERSION}.tar.gz && \
    tar -zxvf ${NGINX_VERSION}.tar.gz && \
    cd /tmp/src/${NGINX_VERSION} && \
    ./configure --prefix=/etc/nginx \
                --http-log-path=/var/log/nginx/access.log \
                --error-log-path=/var/log/nginx/error.log \
                --sbin-path=/usr/local/sbin/nginx && \
    make && make install && \
    apk del build-base && \
    rm -rf /tmp/src && \
    rm -rf /var/cache/apk/* && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

COPY nginx.conf /etc/nginx/conf/nginx.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
