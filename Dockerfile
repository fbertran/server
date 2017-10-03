FROM cosyverif/docker-images:openresty
MAINTAINER Alban Linard <alban@linard.fr>

ADD .           /src/cosy/server
ADD mime.types  /mime.types
ADD nginx.conf  /nginx.conf

RUN     apk add --no-cache --virtual .build-deps \
            build-base \
            make \
            perl \
            openssl-dev \
    &&  cd /src/cosy/server/ \
    &&  luarocks install rockspec/lua-resty-qless-develop-0.rockspec \
    &&  luarocks install rockspec/hashids-develop-0.rockspec \
    &&  luarocks make    rockspec/cosy-server-master-1.rockspec \
    &&  rm -rf /src/cosy/server \
    &&  apk del .build-deps

ENTRYPOINT ["cosy-server"]
CMD [""]
