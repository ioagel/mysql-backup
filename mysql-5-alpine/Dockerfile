FROM alpine

MAINTAINER Ioannis Angelakopoulos<ioagel@gmail.com>

RUN apk add --no-cache mysql-client bash xz openssl && \
  mkdir /backup

COPY mysql_backup.sh /mysql_backup.sh

VOLUME ["/backup"]

CMD ["bash", "/mysql_backup.sh"]
