FROM alpine

MAINTAINER Ioannis Angelakopoulos<ioagel@gmail.com>

RUN apk add --no-cache mysql-client bash

RUN wget --no-check-certificate -P /usr/local/bin \
  https://gist.githubusercontent.com/ioagel/952aa6c1739e355354fec7ccc8d144bf/raw/96be4c915128b43ae91be358364216580a304b78/mysql_backup.sh && \
  chmod +x /usr/local/bin/mysql_backup.sh

CMD ["mysql_backup.sh"]
