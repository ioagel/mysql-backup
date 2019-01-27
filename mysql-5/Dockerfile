FROM mysql:5.7

MAINTAINER Ioannis Angelakopoulos<ioagel@gmail.com>

RUN apt-get update && \
  apt-get install -y --no-install-recommends bzip2 xz-utils cron && \
  rm -rf /var/lib/apt/lists/* \
  mkdir /backup

COPY mysql_backup.sh start.sh /
#COPY environment /etc/environment

VOLUME ["/backup"]

CMD ["/bin/bash", "/start.sh"]
