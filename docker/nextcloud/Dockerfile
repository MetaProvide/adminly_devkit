FROM golang:1.18-bullseye as supercronic

ENV SUPERCRONIC_VERSION v0.1.12

# hadolint ignore=DL3003
RUN set -ex; \
    git clone --branch $SUPERCRONIC_VERSION https://github.com/aptible/supercronic; \
    cd supercronic; \
    go mod vendor; \
    go install;

FROM nextcloud:24

COPY --from=supercronic /go/bin/supercronic /usr/local/bin/supercronic

RUN set -ex; \
    \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        supervisor \
    ; \
    rm -rf /var/lib/apt/lists/*; \
    \
    chmod +x /usr/local/bin/supercronic; \
    echo '*/5 * * * * php -f /var/www/html/cron.php' > /crontab; \
    \
	pecl install xdebug; \
    docker-php-ext-enable xdebug; \
    mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"; \
    \
    { \
        echo "xdebug.mode = debug"; \
        echo "xdebug.start_with_request = yes"; \
        echo "xdebug.client_host=host.docker.internal"; \
		echo "memory_limit=1024M"; \
        echo "upload_max_filesize=16G"; \
        echo "post_max_size=16G"; \
        echo "max_execution_time=3600"; \
        echo "max_input_time=3600"; \
    } > /usr/local/etc/php/conf.d/nextcloud.ini;

ENV NEXTCLOUD_UPDATE=1

COPY supervisord.conf /

CMD ["/usr/bin/supervisord", "-c", "/supervisord.conf"]
