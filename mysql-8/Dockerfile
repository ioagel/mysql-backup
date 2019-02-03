FROM mysql:8

MAINTAINER Ioannis Angelakopoulos<ioagel@gmail.com>

RUN apt-get update && \
  apt-get install -y --no-install-recommends bzip2 xz-utils cron msmtp ca-certificates && \
  rm -rf /var/lib/apt/lists/* \
  mkdir /backup

RUN update-ca-certificates
COPY mysql_backup.sh start.sh /

VOLUME ["/backup"]

CMD ["/bin/bash", "/start.sh"]
