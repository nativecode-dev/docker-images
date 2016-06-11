FROM wordpress:latest
RUN set -x \
  && docker-php-ext-install zip \
;

ADD docker-entrypoint.sh /entrypoint.sh
