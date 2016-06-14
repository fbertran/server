FROM debian:testing
MAINTAINER Alban Linard <alban@linard.fr>

RUN apt-get  update  --yes
RUN apt-get  install --yes luajit luarocks
RUN luarocks install cosy-editor
ENTRYPOINT ["cosy-editor"]
CMD ["--help"]
