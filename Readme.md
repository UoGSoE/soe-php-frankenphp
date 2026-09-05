# soe-php-frankenphp

Base docker image for our Laravel apps: PHP 8.x running under [FrankenPHP](https://frankenphp.dev/) on Debian bookworm, with the PHP extensions and OS tools our apps rely on. It is the successor to `uogsoe/soe-php-apache`.

## Using it

```dockerfile
FROM uogsoe/soe-php-frankenphp:8.4
```

Tags exist for PHP 8.2, 8.3, 8.4 and 8.5. Images are built for `linux/amd64` only.

With no `CMD` the image runs in classic mode, serving `/app/public` over plain http on port 6060 (TLS is terminated upstream of the container). Apps using Laravel Octane override `CMD`:

```dockerfile
CMD ["php", "artisan", "octane:frankenphp", "--host=0.0.0.0", "--port=6060", "--workers=4"]
```

Set `--workers` explicitly. Octane defaults it to the host's CPU count, which is wrong on a swarm node hosting many apps.

## Differences from the apache image

- The container runs as `www-data`, not root. Nothing in the image needs root at runtime, so there is no `gosu` step. In an app Dockerfile, `COPY --chown=www-data:www-data` anything the app writes to, such as `storage/` and `bootstrap/cache/`. `/run/secrets` exists and is writable by www-data, so a CI job can place a `.env` there the way swarm does.
- The app listens on port 6060, not 80. An unprivileged user cannot bind port 80, and 6060 is not something else's default. Point the Traefik `loadbalancer.server.port` label at 6060.
- The work directory is `/app`, not `/var/www/html`.
- There is no `apache2-foreground`. The upstream entrypoint starts FrankenPHP.
- Plain http only. `SERVER_NAME=:6060` stops Caddy enabling automatic https and redirecting plain http.
- The old `X-Container` response header from the apache vhost is not set.

## What is in the image

PHP extensions: bcmath, exif, gd, gmp, intl, ldap, pcntl, pdo_mysql, redis, sysvmsg, zip. The curl, mbstring, sqlite3 and xml extensions come compiled into the upstream image.

OS tools: tini, gosu, netcat-openbsd, sqlite3, unzip, vim-tiny, git. Composer is installed at a pinned version.

Timezone and language default to Europe/London and en_GB.UTF-8. The ini files in this repo set upload limits, the PHP timezone, and `variables_order = EGPCS` so docker environment variables land in `$_ENV`.

If an app needs extra extensions, install them in the app's own Dockerfile with `install-php-extensions` and pin the versions.

## Building locally

```sh
docker build --build-arg PHP_VERSION=8.5 -t soe-php-frankenphp:8.5 .
```

## Publishing

The GitHub Actions workflow in `.github/workflows/main.yml` builds every supported PHP version and pushes to Docker Hub. It is manual dispatch only for now.

## License

MIT. See the LICENSE file.

