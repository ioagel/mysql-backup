FROM alpine:3.8

MAINTAINER Ioannis Angelakopoulos<ioagel@gmail.com>

RUN apk add --no-cache mysql-client bash xz openssl && \
  mkdir /backup

COPY mysql_backup.sh start.sh /

VOLUME ["/backup"]

CMD ["/bin/bash", "/start.sh"]
