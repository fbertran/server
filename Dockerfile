FROM erikcw/lapis
MAINTAINER Alban Linard <alban@linard.fr>

ADD . /src/cosy/server
ADD mime.types /opt/openresty/nginx/conf/mime.types
ADD nginx.conf /opt/openresty/nginx/conf/nginx.conf
RUN luarocks install luasec OPENSSL_LIBDIR="/lib/x86_64-linux-gnu/"
RUN luarocks install https://raw.githubusercontent.com/un-def/hashids.lua/master/hashids-1.0.2-1.rockspec
RUN cd /src/cosy/server/ && \
    luarocks make rockspec/cosy-server-master-1.rockspec && \
    cd /
RUN rm -rf /src/cosy/server
ENTRYPOINT ["cosy-server"]
CMD [""]
