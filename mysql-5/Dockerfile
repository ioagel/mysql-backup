FROM mysql:5.7

MAINTAINER Ioannis Angelakopoulos<ioagel@gmail.com>

RUN apt-get update && apt-get install -y --no-install-recommends bzip2 xz-utils && rm -rf /var/lib/apt/lists/*

COPY mysql_backup.sh /usr/local/bin/
RUN chmod 755 /usr/local/bin/mysql_backup.sh

CMD ["mysql_backup.sh"]
