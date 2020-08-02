FROM debian:10.4-slim AS builder

LABEL maintainer="FrangaL <frangal@gmail.com>"

ENV NGINX_PATH /etc/nginx
ENV NGINX_VERSION 1.16.1

WORKDIR /opt

RUN apt-get update && \
    apt-get install -y libpcre3 libpcre3-dev zlib1g-dev zlib1g golang-go build-essential git curl cmake;

RUN curl -O https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz && \
    tar xvzf nginx-$NGINX_VERSION.tar.gz && \
    git clone --recursive https://github.com/cloudflare/quiche && \
    git clone --recursive https://github.com/google/ngx_brotli.git && \
    cd nginx-$NGINX_VERSION && \
    patch -p01 < ../quiche/extras/nginx/nginx-1.16.patch && \
    curl https://sh.rustup.rs -sSf | sh -s -- -y -q && \
    export PATH="$HOME/.cargo/bin:$PATH" && \
    ./configure            	\
    --prefix=$NGINX_PATH \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib/nginx/modules \
    --conf-path=$NGINX_PATH/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --user=www-data \
    --group=www-data  \
    --with-compat \
    --with-file-aio \
    --with-threads \
    --with-http_addition_module \
    --with-http_auth_request_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_mp4_module \
    --with-http_random_index_module \
    --with-http_realip_module \
    --with-http_secure_link_module \
    --with-http_slice_module \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-http_sub_module \
    --with-http_v2_module \
    --with-mail \
    --with-mail_ssl_module \
    --with-stream \
    --with-stream_realip_module \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --add-module=/opt/ngx_brotli \
    --with-http_v3_module 	\
    --with-openssl=/opt/quiche/deps/boringssl \
    --build="quiche-$(git --git-dir=../quiche/.git rev-parse --short HEAD)" \
    --with-quiche=/opt/quiche &&\
    make && \
    make install;

FROM debian:10.4-slim

COPY --from=builder /usr/sbin/nginx /usr/sbin/
COPY --from=builder /etc/nginx/ /etc/nginx/

RUN echo -e "\
user www-data;\n\
worker_processes auto;\n\
pid /run/nginx.pid;\n\
include /etc/nginx/modules-enabled/*.conf;\n\
\n\
events {\n\
        worker_connections 768;\n\
        multi_accept on;\n\
}\n\
\n\
http {\n\
\n\
        # Basic Settings\n\
        sendfile on;\n\
        tcp_nopush on;\n\
        tcp_nodelay on;\n\
        keepalive_timeout 65;\n\
        types_hash_max_size 2048;\n\
        # server_tokens off;\n\
        # server_names_hash_bucket_size 64;\n\
        # server_name_in_redirect off;\n\
\n\
        include /etc/nginx/mime.types;\n\
        default_type application/octet-stream;\n\
\n\
        # SSL Settings\n\
        ssl_protocols TLSv1.2 TLSv1.3;\n\
        ssl_prefer_server_ciphers on;\n\
\n\
        # Logging Settings\n\
        access_log /var/log/nginx/access.log;\n\
        error_log /var/log/nginx/error.log;\n\
\n\
        # Gzip Settings\n\
        gzip off;\n\
        # Brotli Settings\n\
        brotli_static   off;\n\
        brotli          off;\n\

        # Virtual Host Configs\n\
        include /etc/nginx/conf.d/*.conf;\n\
        include /etc/nginx/sites-enabled/*;\n\
}\n\
" > /etc/nginx/nginx.conf

RUN mkdir -p /etc/nginx/sites-enabled && \
echo -e "\
server {\n\
    listen 80;\n\
    listen [::]:80;\n\
    server_name _;\n\
\n\
    #charset koi8-r;\n\
\n\
    access_log off;\n\
    #access_log /var/log/nginx/access.log main;\n\
\n\
    location / {\n\
        root   /var/www/html;\n\
        index  index.html index.htm;\n\
    }\n\
}\n\
" > /etc/nginx/sites-enabled/00-default

RUN mkdir -p /var/log/nginx \
  && mkdir -p /etc/nginx/conf.d \
  && mkdir -p /etc/nginx/modules-enabled \
  && mkdir -p /var/www/html \
  && rm -rf /etc/nginx/html \
  && touch /var/log/nginx/access.log /var/log/nginx/error.log \
  && chown www-data:www-data /var/www/ -R \
  && chown www-data:www-data /var/log/nginx/access.log /var/log/nginx/error.log \
  && ln -sf /dev/stdout /var/log/nginx/access.log \
  && ln -sf /dev/stderr /var/log/nginx/error.log

COPY --chown=www-data:www-data --from=builder /etc/nginx/html/index.html /var/www/html

EXPOSE 80 443
EXPOSE 443/udp

STOPSIGNAL SIGTERM

CMD ["nginx", "-g", "daemon off;"]

# Build-time metadata as defined at http://label-schema.org
ARG VCS_REF

LABEL org.label-schema.build-date=$BUILD_DATE \
  org.label-schema.version="$NGINX_VERSION" \
  org.label-schema.docker.schema-version="1.0" \
  org.label-schema.name="docker-nginx-http3" \
  org.label-schema.description="Docker image for Nginx + HTTP/3 powered by Quiche" \
  org.label-schema.vcs-ref=$VCS_REF \
  org.label-schema.vcs-url="https://github.com/FrangaL/docker-nginx-http3" \
  org.label-schema.docker.cmd= "docker run --name nginx-http3 -d -p 80:80 -p 443:443/tcp -p 443:443/udp nginx:$NGINX_VERSION"
