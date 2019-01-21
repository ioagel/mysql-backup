FROM mysql:5.7

MAINTAINER Ioannis Angelakopoulos<ioagel@gmail.com>

RUN apt-get update && \
  apt-get install -y --no-install-recommends bzip2 xz-utils && \
  rm -rf /var/lib/apt/lists/* \
  mkdir /backup

COPY mysql_backup.sh /mysql_backup.sh

VOLUME ["/backup"]

CMD ["bash", "/mysql_backup.sh"]
