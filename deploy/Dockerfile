# syntax=docker/dockerfile:1

ARG PHP_VERSION=8.3

FROM php:${PHP_VERSION}-fpm-bookworm AS base

ARG PHPREDIS_VERSION=6.3.0
ARG PHPREDIS_SHA256=cb8f81df1a275599e4f8ddcfec7e1f65ed1953e6f5673649149fd680ebff4cad

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        default-mysql-client \
        gzip \
        libcurl4-openssl-dev \
        libicu-dev \
        libonig-dev \
        libzip-dev \
        openssl \
        supervisor \
        tar \
    && docker-php-ext-install -j"$(nproc)" \
        bcmath \
        curl \
        intl \
        mbstring \
        opcache \
        pcntl \
        pdo_mysql \
        zip \
    # PECL's legacy client can time out against pecl.php.net in container networks.
    # Fetch the pinned phpredis source from its official upstream release instead.
    && curl --fail --silent --show-error --location --retry 3 --retry-delay 2 \
        --output /tmp/phpredis.tar.gz \
        "https://github.com/phpredis/phpredis/archive/refs/tags/${PHPREDIS_VERSION}.tar.gz" \
    && echo "${PHPREDIS_SHA256}  /tmp/phpredis.tar.gz" | sha256sum --check --strict \
    && mkdir -p /usr/src/php/ext/redis \
    && tar -xzf /tmp/phpredis.tar.gz --strip-components=1 -C /usr/src/php/ext/redis \
    && docker-php-ext-install redis \
    && rm -rf /tmp/phpredis.tar.gz /usr/src/php/ext/redis \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /var/www/html

FROM composer:2.8 AS composer

FROM base AS vendor

COPY --from=composer /usr/bin/composer /usr/local/bin/composer
COPY app/composer.json app/composer.lock ./

RUN composer install \
    --no-dev \
    --prefer-dist \
    --no-interaction \
    --no-progress \
    --no-scripts \
    --optimize-autoloader

COPY app/ ./

RUN composer dump-autoload \
    --no-dev \
    --classmap-authoritative \
    --no-interaction

FROM base AS runtime

COPY --from=vendor --chown=www-data:www-data /var/www/html /var/www/html
COPY deploy/php/conf.d/production.ini /usr/local/etc/php/conf.d/99-production.ini
COPY deploy/php/docker-entrypoint.sh /usr/local/bin/vetoapp-entrypoint
COPY deploy/supervisor/ /etc/supervisor/
COPY deploy/scripts/backup.sh /usr/local/bin/vetoapp-backup
COPY deploy/scripts/backup-loop.sh /usr/local/bin/vetoapp-backup-loop

RUN ln -sfn ../storage/app/public public/storage \
    && mkdir -p \
        storage/framework/cache/data \
        storage/framework/sessions \
        storage/framework/views \
        storage/logs \
        bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache \
    && chmod +x \
        /usr/local/bin/vetoapp-entrypoint \
        /usr/local/bin/vetoapp-backup \
        /usr/local/bin/vetoapp-backup-loop

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/vetoapp-entrypoint"]
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord-app.conf"]
