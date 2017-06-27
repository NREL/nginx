FROM alpine:3.6

ENV NGINX_VER 1.13.1
ENV UPLOADPROGRES_VER 0.9.1
ENV GOTPL_VER 0.1.5
ENV PAGESPEED_VER 1.12.34.2
ENV LIBPNG_VER 1.2.57

ENV GOTPL_URL https://github.com/wodby/gotpl/releases/download/${GOTPL_VER}/gotpl-alpine-linux-amd64-${GOTPL_VER}.tar.gz
ENV NGINX_URL http://nginx.org/download/nginx-${NGINX_VER}.tar.gz
ENV UPLOADPROGRES_URL https://github.com/masterzen/nginx-upload-progress-module/archive/v${UPLOADPROGRES_VER}.tar.gz
ENV NPS_URL https://github.com/pagespeed/ngx_pagespeed/archive/v${PAGESPEED_VER}-stable.tar.gz
ENV PAGESPEED_URL https://dl.google.com/dl/linux/mod-pagespeed/tar/stable/mod-pagespeed-stable-${PAGESPEED_VER}-r0.tar.bz2

ENV HTML_DIR /var/www/html

COPY patches /usr/src/patches

RUN set -ex && \

    addgroup -S -g 82 www-data && \
    adduser -S -u 82 -s /bin/bash -D -G www-data www-data && \

    addgroup -S nginx && \
    adduser -S -D -H -h /var/lib/nginx -s /sbin/nologin -G nginx -g nginx nginx && \
    addgroup nginx www-data && \

    apk add --update --no-cache --virtual .nginx-rundeps \
        apr \
        apr-util \
        bash \
        ca-certificates \
        curl \
        geoip \
        icu \
        icu-libs \
        libjpeg-turbo \
        libressl \
        libuuid \
        make \
        patch \
        pcre \
        su-exec \
        wget \
        zlib && \

    apk add --update --no-cache --virtual .build-deps \
        apache2-dev \
        apr-dev \
        apr-util-dev \
        autoconf \
        build-base \
        geoip-dev\
        gperf \
        icu-dev \
        libjpeg-turbo-dev \
        libressl-dev \
        libtool \
        linux-headers \
        pcre-dev \
        python \
        zlib-dev && \

    wget -qO- ${GOTPL_URL} | tar xz -C /usr/local/bin && \
    wget -qO- ${NGINX_URL} | tar xz -C /tmp/ && \
    wget -qO- ${UPLOADPROGRES_URL} | tar xz -C /tmp/ && \

    # Libpng
    wget -qO- http://prdownloads.sourceforge.net/libpng/libpng-${LIBPNG_VER}.tar.gz | tar -xz -C /tmp && \
    cd /tmp/libpng-${LIBPNG_VER} && \
    ./configure --build=$CBUILD --host=$CHOST --prefix=/usr --enable-shared --with-libpng-compat && \
    make install V=0 && \

    # Pagespeed
    wget -qO- ${NPS_URL} | tar xz -C /tmp/ && \
    wget -qO- ${PAGESPEED_URL} | tar xj -C /tmp/ && \
    nps_dir=/tmp/ngx_pagespeed-${PAGESPEED_VER}-stable && \
    ps_dir=/tmp/modpagespeed-${PAGESPEED_VER} && \

    cd ${ps_dir} && \
    patch -tp1 < /usr/src/patches/automatic_makefile.patch && \
    patch -tp1 < /usr/src/patches/mod-pagespeed-re2.patch && \
    patch -p1 < /usr/src/patches/libpng_cflags.patch && \
    patch -p1 < /usr/src/patches/pthread_nonrecursive_np.patch && \
    patch -p1 < /usr/src/patches/rename_c_symbols.patch && \
    patch -p1 < /usr/src/patches/stack_trace_posix.patch && \

    ## Update grpc
    rm -rf ${ps_dir}/src/third_party/grpc/src && \
    mkdir ${ps_dir}/src/third_party/grpc/src && \
    wget -qO- https://github.com/grpc/grpc/archive/v1.3.0.tar.gz | tar -xz --strip-components=1 -C ${ps_dir}/src/third_party/grpc/src && \

    ./generate.sh -D use_system_libs=1 -D _GLIBCXX_USE_CXX11_ABI=0 -D use_system_icu=1 && \

    cflags=" -I/usr/include/apr-1 -I/tmp/libpng-${LIBPNG_VER} -fPIC -D_GLIBCXX_USE_CXX11_ABI=0" && \

    cd ${ps_dir}/src && \
    make BUILDTYPE=Release CXXFLAGS="${cflags}" CFLAGS="${cflags}" && \

    cd ${ps_dir}/src/pagespeed/automatic/ && \
    make psol BUILDTYPE=Release CXXFLAGS="${cflags}" CFLAGS="${cflags}" && \

    cp -r ${ps_dir}/src/out/Release/obj ${nps_dir}/psol/include/out/Release/ && \
    cp -r ${ps_dir}/src/net ${nps_dir}/psol/include/ && \
    cp -r ${ps_dir}/src/testing ${nps_dir}/psol/include/ && \
    cp -r ${ps_dir}/src/pagespeed ${nps_dir}/psol/include/ && \
    cp -r ${ps_dir}/src/third_party ${nps_dir}/psol/include/ && \
    cp -r ${ps_dir}/src/tools ${nps_dir}/psol/include/ && \
    cp -r ${ps_dir}/src/pagespeed/automatic/pagespeed_automatic.a ${nps_dir}/psol/lib/Release/linux/x64 && \

    trap "cat /tmp/nginx-1.13.1/objs/autoconf.err" EXIT && \

    # Build nginx with modules
    cd /tmp/nginx-${NGINX_VER} && \
    ./configure \
        --prefix=/usr/share/nginx \
        --sbin-path=/usr/sbin/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --group=nginx \
        --http-client-body-temp-path=/var/lib/nginx/tmp/client_body \
        --http-fastcgi-temp-path=/var/lib/nginx/tmp/fastcgi \
        --http-proxy-temp-path=/var/lib/nginx/tmp/proxy \
        --http-scgi-temp-path=/var/lib/nginx/tmp/scgi \
        --http-uwsgi-temp-path=/var/lib/nginx/tmp/uwsgi \
        --lock-path=/var/run/nginx/nginx.lock \
        --user=nginx \
        --pid-path=/var/run/nginx/nginx.pid \
        --with-cc-opt="-fPIC -I /usr/include/apr-1" \
        --with-file-aio \
        --with-pcre-jit \
        --with-http_addition_module \
        --with-http_auth_request_module \
        --with-http_dav_module \
        --with-http_flv_module \
        --with-http_geoip_module \
        --with-http_gunzip_module \
        --with-http_gzip_static_module \
        --with-http_mp4_module \
        --with-http_random_index_module \
        --with-http_realip_module \
        --with-http_secure_link_module \
        --with-http_ssl_module \
        --with-http_stub_status_module \
        --with-http_sub_module \
        --with-http_v2_module \
        --with-ipv6 \
        --with-ld-opt="-Wl,-rpath,/usr/lib/,-luuid -lapr-1 -laprutil-1 -licudata -licuuc -L/tmp/modpagespeed-${PAGESPEED_VER}/usr/lib -lpng12 -lturbojpeg -ljpeg" \
        --with-mail \
        --with-mail_ssl_module \
        --with-stream \
        --with-stream_ssl_module \
        --with-threads \
        --add-module=/tmp/nginx-upload-progress-module-${UPLOADPROGRES_VER} \
        --add-module=/tmp/ngx_pagespeed-${UPLOADPROGRES_VER}-stable && \

    make -j2 && \
    make install && \

    mkdir -p /var/cache/ngx_pagespeed && \
    chmod -R o+wr /var/cache/ngx_pagespeed && \
    mkdir /etc/nginx/conf.d && \
    mkdir -p /var/lib/nginx/tmp && \
    chmod 755 /var/lib/nginx && \
    chmod -R 777 /var/lib/nginx/tmp && \
    mkdir -p /etc/nginx/pki && \
    chmod 400 /etc/nginx/pki && \

    # Cleanup
    apk del .build-deps && \
    rm -rf /tmp/*

COPY actions /usr/local/bin

WORKDIR $HTML_DIR
EXPOSE 80

COPY templates/* /etc/gotpl/
COPY docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["nginx"]
