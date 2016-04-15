FROM debian:testing
MAINTAINER Alban Linard <alban@linard.fr>

RUN apt-get update
RUN apt-get --yes install sudo git

ADD . /home/cosy/environment
RUN chown -R root.users /home/cosy

RUN cd /home/cosy/environment && ./bin/install --in-ci --prefix=/app && rm -rf /home/cosy/environment
RUN chown -R root.users /app
