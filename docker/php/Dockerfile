ARG PHP_BASE_IMAGE=wodby/wordpress-php:8.4-4.80.9

FROM ${PHP_BASE_IMAGE}

LABEL maintainer="Igor Tron <public@itron.pro>"

ARG GRC_COMMIT=f4a579e08d356a3ea00a8c6fda7de84fff5f676a
ARG GRCAT_SHA256=72c5308e7a1fcf7b68d97fe215faa12aa378b466f6b58e2c068dbb176bbb331f

USER root

RUN set -eux; \
    apk add --no-cache python3; \
    curl --fail --location --silent --show-error \
        "https://raw.githubusercontent.com/garabik/grc/${GRC_COMMIT}/grcat" \
        --output /tmp/grcat; \
    echo "${GRCAT_SHA256}  /tmp/grcat" | sha256sum -c -; \
    install -m 0755 /tmp/grcat /usr/local/bin/grcat; \
    rm /tmp/grcat; \
    mkdir -p /home/wodby/.grc /home/wodby/.wp-cli /var/log/php; \
    touch /var/log/php/error.log /var/log/php/xdebug.log; \
    chown -R wodby:wodby /home/wodby/.grc /home/wodby/.wp-cli /var/log/php

COPY php.ini /usr/local/etc/php/conf.d/zzzz-local-dev.ini
COPY --chown=wodby:wodby grc.php.log.conf /home/wodby/.grc/grc.php.log.conf
COPY --chown=wodby:wodby wp-cli.yml /home/wodby/.wp-cli/config.yml

WORKDIR /srv/web

USER wodby
