# docker build --no-cache=true -t vod:ubuntu18.04 -f Dockerfile .
FROM ubuntu:18.04

ENV NGINX_VERSION nginx-1.17.9
ENV NGINX_RTMP_MODULE_VERSION 1.2.1
ENV RECORD_DIR /record/
ENV RAILS_ROOT /usr/src/app/

RUN mkdir -p $RECORD_DIR && \
    chmod -R 777 $RECORD_DIR && \
    mkdir -p $RAILS_ROOT

ADD node-v12.16.1-linux-x64.tar.xz /
ADD live $RAILS_ROOT

RUN sed "s/archive\.ubuntu\.com/jp\.archive\.ubuntu\.com/" -i /etc/apt/sources.list \
    && sed -i 's/# deb-src/deb-src/g' /etc/apt/sources.list \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
      language-pack-ja \
      tzdata \
      git \
      vim \
      openssl \
      autoconf \
      bison \
      build-essential \
      libyaml-dev \
      libreadline6-dev \
      zlib1g-dev \
      libncurses5-dev \
      libffi-dev \
      libgdbm5 \
      libgdbm-dev \
      libssl1.0.0 \
      libssl1.0-dev \
      libpcre3-dev \
      curl \
      ffmpeg \
      sqlite3 \
      libsqlite3-dev \
      supervisor \
      \
      psmisc \
      procps \
      dstat \
      iputils-ping \
      net-tools \
      dnsutils \
      jq \
      \
    && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
      yarn \
    && apt-get clean \
    && rm -rf /var/cache/apt/archives/* \
    && rm -rf /var/lib/apt/lists/*

RUN    git clone https://github.com/rbenv/rbenv.git /opt/.rbenv \
    && git clone https://github.com/rbenv/ruby-build.git /opt/.rbenv/plugins/ruby-build \
    && echo 'export RBENV_ROOT="/opt/.rbenv"' >> /etc/profile.d/rbenv.sh \
    && echo 'export PATH="/opt/.rbenv/bin:$PATH"' >> /etc/profile.d/rbenv.sh \
    && echo 'eval "$(rbenv init -)"' >> /etc/profile.d/rbenv.sh

RUN    mv /bin/sh /bin/sh_tmp && ln -s /bin/bash /bin/sh
RUN    source /etc/profile.d/rbenv.sh; \
       LANG=C rbenv install 2.7.0 && rbenv global 2.7.0 && rbenv rehash && gem install bundler -v "2.1.2"
RUN    rm /bin/sh && mv /bin/sh_tmp /bin/sh


# Download and decompress Nginx
RUN mkdir -p /tmp/build/nginx && \
    cd /tmp/build/nginx && \
    curl -L --output ${NGINX_VERSION}.tar.gz https://nginx.org/download/${NGINX_VERSION}.tar.gz && \
    tar -zxf ${NGINX_VERSION}.tar.gz

# Download and decompress RTMP module
RUN mkdir -p /tmp/build/nginx-rtmp-module && \
    cd /tmp/build/nginx-rtmp-module  && \
    curl -L --output nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}.tar.gz https://github.com/arut/nginx-rtmp-module/archive/v${NGINX_RTMP_MODULE_VERSION}.tar.gz && \
    tar -zxf nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}.tar.gz

# Build and install Nginx
# The default puts everything under /usr/local/nginx, so it's needed to change
# it explicitly. Not just for order but to have it in the PATH
RUN cd /tmp/build/nginx/${NGINX_VERSION} && \
    ./configure \
        --sbin-path=/usr/local/sbin/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --pid-path=/var/run/nginx/nginx.pid \
        --lock-path=/var/lock/nginx/nginx.lock \
        --http-log-path=/var/log/nginx/access.log \
        --http-client-body-temp-path=/tmp/nginx-client-body \
        --with-http_ssl_module \
        --with-threads \
        --with-ipv6 \
        --add-module=/tmp/build/nginx-rtmp-module/nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION} && \
    make -j $(getconf _NPROCESSORS_ONLN) && \
    make install && \
    mkdir /var/lock/nginx && \
    rm -rf /tmp/build

# Forward logs to Docker
RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

RUN unlink /usr/bin/node; echo \
    && unlink /usr/bin/nodejs; echo \
    && ln -s /node-v12.16.1-linux-x64/bin/node /usr/bin/node

COPY nginx.conf /etc/nginx/
COPY supervisor.conf /

ENV RBENV_ROOT "/opt/.rbenv"
ENV PATH "/opt/.rbenv/bin:/opt/.rbenv/shims:$PATH"

WORKDIR $RAILS_ROOT

ENV EDITOR cat
RUN bundle install && \
    yarn install && \
    ./bin/rails credentials:edit && \
    ./bin/rake assets:precompile RAILS_ENV=production

ENV EDITOR vim

EXPOSE 1935 80 443

CMD ["supervisord", "-c", "/supervisor.conf"]
