FROM debian:buster-slim AS builder

LABEL maintainer="FrangaL <frangal@gmail.com>"

ENV LC_ALL C
ENV DEBIAN_FRONTEND noninteractive
ENV NGINX_PATH /etc/nginx
ENV NGINX_VERSION 1.16.1

WORKDIR /opt

RUN apt-get update && \
    apt-get install -y libpcre3 libpcre3-dev zlib1g-dev zlib1g build-essential git curl cmake;

RUN curl -O https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz && \
    tar xvzf nginx-$NGINX_VERSION.tar.gz && \
    git clone --recursive https://github.com/cloudflare/quiche && \
    git clone --recursive https://github.com/google/ngx_brotli.git && \
    git clone --depth=1 --recursive https://github.com/openresty/headers-more-nginx-module && \
    cd nginx-$NGINX_VERSION && \
    patch -p01 < ../quiche/extras/nginx/nginx-1.16.patch && \
    curl https://sh.rustup.rs -sSf | sh -s -- -y -q && \
    export PATH="$HOME/.cargo/bin:$PATH" && \
    ./configure \
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
    --add-module=/opt/headers-more-nginx-module \
    --with-http_v3_module \
    --with-openssl=/opt/quiche/deps/boringssl \
    --build="quiche-$(git --git-dir=../quiche/.git rev-parse --short HEAD)" \
    --with-quiche=/opt/quiche &&\
    make && make install;

FROM debian:buster-slim

COPY --from=builder /usr/sbin/nginx /usr/sbin/
COPY --from=builder /etc/nginx/ /etc/nginx/

RUN mkdir -p /var/log/nginx \
  && mkdir -p /var/cache/nginx/{client_temp,fastcgi_temp,proxy_temp} \
  && mkdir -p /var/www \
  && mkdir -p /etc/nginx/{sites-available,sites-enabled,certs} \
  && touch touch /var/log/nginx/{error,access}.log \
  && chown www-data:www-data /var/log/nginx/ -R \
  && chown www-data:www-data /var/cache/nginx/ -R \
  && chown www-data:www-data /var/www \
  && ln -sf /dev/stdout /var/log/nginx/access.log \
  && ln -sf /dev/stderr /var/log/nginx/error.log \
  && sed -i '4s/^/<link rel="icon" href="data:,"> /' /etc/nginx/html/index.html

EXPOSE 80

STOPSIGNAL SIGTERM

CMD ["nginx", "-g", "daemon off;"]

# Build-time metadata as defined at http://label-schema.org
ARG VCS_REF

LABEL org.label-schema.build-date="$BUILD_DATE" \
  org.label-schema.version="$NGINX_VERSION" \
  org.label-schema.docker.schema-version="1.0" \
  org.label-schema.name="docker-nginx-http3" \
  org.label-schema.description="Docker image for Nginx + HTTP/3 powered by Quiche" \
  org.label-schema.vcs-ref=$VCS_REF \
  org.label-schema.vcs-url="https://github.com/FrangaL/docker-nginx-http3"
