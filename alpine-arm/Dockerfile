FROM arm32v7/alpine

MAINTAINER Ioannis Angelakopoulos<ioagel@gmail.com>

RUN apk add --no-cache mysql-client bash xz openssl msmtp ca-certificates && \
  mkdir /backup

RUN update-ca-certificates

COPY mysql_backup.sh start.sh /

VOLUME ["/backup"]

CMD ["/bin/bash", "/start.sh"]
