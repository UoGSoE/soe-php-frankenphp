# soe-php-frankenphp

Base docker image for our Laravel apps: PHP 8.x running under [FrankenPHP](https://frankenphp.dev/) on Debian bookworm, with the PHP extensions and OS tools our apps rely on. It is the successor to `uogsoe/soe-php-apache`.

## Using it

```dockerfile
FROM uogsoe/soe-php-frankenphp:8.4
```

Tags exist for PHP 8.2, 8.3, 8.4 and 8.5. Images are built for `linux/amd64` only.

With no `CMD` the image runs in classic mode, serving `/app/public` over plain http on port 80 (TLS is terminated upstream of the container). Apps using Laravel Octane override `CMD`:

```dockerfile
CMD ["php", "artisan", "octane:frankenphp", "--host=0.0.0.0", "--port=80", "--workers=4"]
```

Set `--workers` explicitly. Octane defaults it to the host's CPU count, which is wrong on a swarm node hosting many apps.

## Differences from the apache image

- The work directory is `/app`, not `/var/www/html`.
- There is no `apache2-foreground`. The upstream entrypoint starts FrankenPHP.
- Plain http only. `SERVER_NAME=:80` stops Caddy enabling automatic https and redirecting plain http.
- The old `X-Container` response header from the apache vhost is not set.

## What is in the image

PHP extensions: bcmath, exif, gd, gmp, ldap, pcntl, pdo_mysql, redis, sysvmsg, zip. The curl, mbstring, sqlite3 and xml extensions come compiled into the upstream image.

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
