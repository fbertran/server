FROM debian:testing
MAINTAINER Alban Linard <alban@linard.fr>

ADD . /src/cosy/server

RUN apt-get update && \
    apt-get --yes install git && \
    chown -R root.users /src/cosy/server && \
    cd /src/cosy/server && ./bin/install --prefix=/app --in-ci && cd / && \
    chown -R root.users /app && \
    apt-get --yes autoremove && \
    apt-get clean && \
    rm -rf /src/cosy/server /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENTRYPOINT ["/app/bin/cosy-server"]
CMD ["--help"]
