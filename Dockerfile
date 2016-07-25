FROM erikcw/lapis
MAINTAINER Alban Linard <alban@linard.fr>

ADD . /src/cosy/server
ADD config.lua      /opt/openresty/nginx/conf/config.lua
ADD migrations.lua  /opt/openresty/nginx/conf/migrations.lua
ADD models.lua      /opt/openresty/nginx/conf/models.lua
ADD mime.types      /opt/openresty/nginx/conf/mime.types
ADD nginx.conf      /opt/openresty/nginx/conf/nginx.conf
RUN apt-get update  --yes
RUN apt-get install --yes git libssl-dev
RUN luarocks install luasec OPENSSL_LIBDIR="/lib/x86_64-linux-gnu/"
RUN cd /src/cosy/server/ && \
    luarocks make rockspec/cosy-server-master-1.rockspec && \
    cd /
RUN cd /src/cosy/server/ && \
    mkdir -p /usr/share/cosy/server/ && \
    git rev-parse --abbrev-ref HEAD > /usr/share/cosy/server/VERSION && \
    cd /
RUN rm -rf /src/cosy/server
ENTRYPOINT ["cosy-server"]
CMD [""]
