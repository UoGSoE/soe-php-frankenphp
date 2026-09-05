ARG FRANKENPHP_VERSION=1
ARG PHP_VERSION=8.5
ARG DEBIAN_VERSION=bookworm

FROM dunglas/frankenphp:${FRANKENPHP_VERSION}-php${PHP_VERSION}-${DEBIAN_VERSION}

ARG PHP_VERSION=8.5
ARG PHP_REDIS_VERSION=6.3.0
ARG COMPOSER_VERSION=2.10.0
ARG DEBIAN_FRONTEND=noninteractive

LABEL org.opencontainers.image.source="https://github.com/UoGSoE/soe-php-frankenphp" \
      org.opencontainers.image.vendor="University of Glasgow, School of Engineering" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.title="PHP ${PHP_VERSION} + FrankenPHP" \
      org.opencontainers.image.description="PHP ${PHP_VERSION} with FrankenPHP and a set of php/os packages suitable for running Laravel apps under Octane"

# our default timezone and language
ENV TZ=Europe/London
ENV LANG=en_GB.UTF-8

# serve plain http on :6060 - tls is terminated upstream of the container.
# without an explicit SERVER_NAME caddy assumes 'localhost', turns on
# automatic https and 308-redirects all plain-http requests.  6060 rather
# than 80 so the container can run as an unprivileged user (see USER below)
ENV SERVER_NAME=:6060
EXPOSE 6060

# Note: FrankenPHP ships a ZTS build of php on the official docker-library
#       lineage, so extensions are compiled at build time via
#       install-php-extensions (bundled in the base image) rather than
#       coming from apt.  We only install reliable/core extensions here -
#       if your app needs custom ones install them in the apps own
#       Dockerfile _and pin the versions_!  (curl, mbstring, sqlite3 and
#       the xml family are already compiled into the official-lineage php.)

RUN install-php-extensions \
        bcmath \
        exif \
        gd \
        gmp \
        ldap \
        pcntl \
        pdo_mysql \
        redis-${PHP_REDIS_VERSION} \
        sysvmsg \
        zip \
    # and some OS tools we use in app start scripts and for debugging
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        tini gosu netcat-openbsd sqlite3 unzip vim-tiny git \
    # clear the apt cache
    && rm -rf /var/lib/apt/lists/* /var/cache/debconf/templates* /var/log/dpkg.log /var/log/apt/term.log /var/cache/debconf/config.dat \
    # install composer
    && curl -o /tmp/composer-setup.php https://getcomposer.org/installer \
    && curl -o /tmp/composer-setup.sig https://composer.github.io/installer.sig \
    && php -r "if (hash('SHA384', file_get_contents('/tmp/composer-setup.php')) !== trim(file_get_contents('/tmp/composer-setup.sig'))) { unlink('/tmp/composer-setup.php'); echo 'Invalid installer' . PHP_EOL; exit(1); }" \
    && php /tmp/composer-setup.php --version=${COMPOSER_VERSION} --no-ansi --install-dir=/usr/local/bin --filename=composer --snapshot \
    && rm -f /tmp/composer-setup.* \
    # set the system timezone
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    # hand the runtime dirs to www-data: caddy writes under /config and /data,
    # /app is where apps live, /var/www is www-data's HOME (composer cache etc)
    && chown -R www-data:www-data /config/caddy /data/caddy /app /var/www

# add in the basic php ini settings for uploading files, our timezone and
# making sure docker env vars land in $_ENV (see variables_order.ini)
COPY uploads.ini timezone.ini variables_order.ini /usr/local/etc/php/conf.d/

# everything from here on (RUN steps in app Dockerfiles, the entrypoint, the
# app itself) runs as www-data, not root.  app Dockerfiles need --chown on
# COPYs of anything the app must write to (storage/, bootstrap/cache/)
USER www-data

# we inherit the upstream image's entrypoint, Caddyfile and /app workdir -
# with no app CMD it serves /app/public in 'classic' (php-fpm-ish) mode.
# octane apps override CMD with something like:
#   CMD ["php", "artisan", "octane:frankenphp", "--host=0.0.0.0", "--port=6060"]
