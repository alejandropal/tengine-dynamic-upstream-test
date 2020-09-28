FROM ubuntu:16.04

RUN NGINX_GPGKEY=573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62; \
	found=''; \
	for server in \
		ha.pool.sks-keyservers.net \
		hkp://keyserver.ubuntu.com:80 \
		hkp://p80.pool.sks-keyservers.net:80 \
		pgp.mit.edu \
	; do \
		echo "Fetching GPG key $NGINX_GPGKEY from $server"; \
		apt-key adv --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$NGINX_GPGKEY" && found=yes && break; \
	done; \
	test -z "$found" && echo >&2 "error: failed to fetch GPG key $NGINX_GPGKEY" && exit 1; \
	echo "deb http://nginx.org/packages/mainline/debian/ jessie nginx" >> /etc/apt/sources.list \
&& apt-get update \
&& apt-get install --no-install-recommends --no-install-suggests -y \
	build-essential \
	libpcre3 \
	libpcre3-dev \
	libssl-dev \
	debhelper \
	git-core \
	libossp-uuid-dev \
	curl \
	patch \
	iputils-ping \
	gcc \
	rsyslog \
	rsyslog-relp \
	netcat \
	tcpdump \
	locales \
	wget \
	unzip \
	software-properties-common \
	moreutils \
&& apt-get clean \
&& rm -rf /var/lib/apt/lists/*

# config workdir
WORKDIR /tmp

# INSTALL OPENRESTY'S LUAJIT, LUA-RESTY-CORE
ENV LUAJIT_LIB=/usr/local/lib
ENV LUAJIT_INC=/usr/local/include/luajit-2.1
ENV LD_LIBRARY_PATH=/usr/local/lib/:/opt/drizzle/lib/:$LD_LIBRARY_PATH
RUN git clone https://github.com/openresty/luajit2 \
&& cd luajit2 && make -j$(nproc) install
RUN git clone https://github.com/openresty/lua-resty-core.git \
&& cd lua-resty-core && git checkout v0.1.17 && make -j$(nproc) install
RUN git clone https://github.com/openresty/lua-resty-lrucache.git \
&& cd lua-resty-lrucache && make -j$(nproc) install

ARG RESTY_LUAROCKS_VERSION="2.3.0"
ENV NGINX_VERSION=2.3.2

WORKDIR /usr/src
RUN curl https://codeload.github.com/alibaba/tengine/tar.gz/${NGINX_VERSION} -o nginx-${NGINX_VERSION}.tar.gz \
&& tar xf nginx-${NGINX_VERSION}.tar.gz && mv tengine-${NGINX_VERSION} nginx-${NGINX_VERSION} \
&& cd /usr/src/nginx-${NGINX_VERSION}/modules && (test -d lua-nginx-module || (git clone https://github.com/openresty/lua-nginx-module.git && cd lua-nginx-module && git checkout v0.10.15)) \
&& cd /usr/src/nginx-${NGINX_VERSION}/modules && (test -d ngx_devel_kit || git clone https://github.com/simplresty/ngx_devel_kit.git) \
&& cd /usr/src/nginx-${NGINX_VERSION} && ./configure \
	--prefix=/usr/local/nginx \
	--with-ld-opt="-Wl,-lossp-uuid,-rpath,${LUAJIT_LIB}" \
	--with-cc-opt="-I/usr/include/ossp" \
	--add-module=/usr/src/nginx-${NGINX_VERSION}/modules/ngx_devel_kit \
	--add-module=/usr/src/nginx-${NGINX_VERSION}/modules/lua-nginx-module \
	--add-module=modules/ngx_http_upstream_dynamic_module \
	--with-http_stub_status_module \
	--http-log-path=/var/log/nginx/access.log \
	--error-log-path=/var/log/nginx/error.log \
&& cd /usr/src/nginx-${NGINX_VERSION} && make -j$(nproc) \
&& cd /usr/src/nginx-${NGINX_VERSION} && make -j$(nproc) install \
&& cd /usr/src \
&& curl -fSL http://luarocks.org/releases/luarocks-${RESTY_LUAROCKS_VERSION}.tar.gz -o luarocks-${RESTY_LUAROCKS_VERSION}.tar.gz \
&& tar xzf luarocks-${RESTY_LUAROCKS_VERSION}.tar.gz \
&& cd luarocks-${RESTY_LUAROCKS_VERSION} \
+&& ./configure \
	--with-lua-bin=/usr/local \
	--lua-suffix=jit \
	--with-lua-include=$LUAJIT_INC \
&& make -j$(nproc) build && make -j$(nproc) install \
&& luarocks install luaposix \
&& rm -rf luarocks-${RESTY_LUAROCKS_VERSION} luarocks-${RESTY_LUAROCKS_VERSION}.tar.gz \
&& apt-get -y remove build-essential  \
&& dpkg --get-selections | awk '{print $1}'|cut -d: -f1|grep -- '-dev$' | xargs apt-get remove -y \
&& rm -rf /usr/src \
&& apt-get clean all \
&& rm -rf /tmp/* \
&& ln -s /usr/local/nginx/sbin/nginx /usr/local/sbin/nginx \
&& ln -sf /dev/stdout /var/log/nginx/access.log \
&& ln -sf /dev/stdout /var/log/nginx/error.log \
&& ln -sf /proc/1/fd/1 /var/log/nginx/refresh_server.log \
&& rm /usr/local/nginx/conf/nginx.conf \
&& sed 's/net.ipv4.tcp_max_syn_backlog.*$/net.ipv4.tcp_max_syn_backlog = 4096/g' -i /etc/sysctl.conf \
&& sed 's/net.core.netdev_max_backlog .*$/net.core.netdev_max_backlog = 5000/g' -i /etc/sysctl.conf \
&& sysctl -p \
&& sed 's/hard nproc.*$/hard nproc 681574/g' -i /etc/security/limits.conf \
&& sed 's/hard nofile.*$/hard nofile 681574/g' -i /etc/security/limits.conf \
&& sed 's/soft nofile.*$/soft nofile 681574/g' -i /etc/security/limits.conf \
&& sed 's/net.ipv4.tcp_max_syn_backlog.*$/net.ipv4.tcp_max_syn_backlog = 4096/g' -i /etc/sysctl.conf \
&& sed 's/net.core.netdev_max_backlog .*$/net.core.netdev_max_backlog = 5000/g' -i /etc/sysctl.conf \
&& sysctl -p

WORKDIR /app

EXPOSE 8080

CMD ["/usr/local/nginx/sbin/nginx"]