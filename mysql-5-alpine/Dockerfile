FROM alpine

MAINTAINER Ioannis Angelakopoulos<ioagel@gmail.com>

RUN apk add --no-cache mysql-client bash xz openssl

COPY mysql_backup.sh /usr/local/bin/
RUN chmod 755 /usr/local/bin/mysql_backup.sh

CMD ["mysql_backup.sh"]
