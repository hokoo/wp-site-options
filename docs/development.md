# Local development

The local stack has exactly three services: nginx, WordPress PHP-FPM, and MySQL 8. WP-CLI and Composer are included in the PHP image; there is no separate tools container. The default URL is `http://wp-site-options.local:8088`.

## Prerequisites

- Docker Engine with Docker Compose v2, or Docker Desktop on macOS/Windows;
- GNU Make;
- Node.js and npm only for the Playwright browser test;
- an available local TCP port (the default is `8088`);
- `sudo` access for the one-time hosts entry on Linux/macOS, or permission to accept a Windows UAC prompt from WSL2.

For WSL2, enable Docker Desktop integration for the distribution containing the checkout. Keep the checkout in the WSL filesystem, such as `/home/<user>/reps/wp-site-options`, rather than under `/mnt/c` or `/mnt/d`.

On native Linux, Docker commands must work for the current user. On macOS, enable Docker file sharing for the checkout when it is outside the default shared locations. The PHP, MySQL, and nginx images support both `amd64` and `arm64`; the stack does not force an architecture on Apple Silicon.

## First setup

Run from the host:

```bash
make setup
```

Setup creates the ignored `.env` when necessary, adds the local hostname, builds the PHP image, starts MySQL and PHP, downloads WordPress, creates or reconciles `wp-config.php`, activates the plugin and fixture, and finally starts nginx. It is idempotent: rerunning it preserves an installed database and updates the configured site URL.

On Linux and macOS, setup may request `sudo` for `/etc/hosts`. Under WSL2 it checks both WSL and Windows; accept the Windows UAC prompt so a browser running on Windows can resolve the domain.

Open `http://wp-site-options.local:8088/wp-admin/`. The setup output reports the exact URL when the port or domain differs.

## Host Make commands

Make is always invoked on the host. Container-dependent targets first start and wait for their required services and then execute the command in the appropriate container.

| Command | Purpose |
| --- | --- |
| `make setup` | Build and reconcile the complete local site. |
| `make up` | Start MySQL, PHP-FPM, and nginx. |
| `make down` | Stop containers while preserving local data. |
| `make reset` | Interactively remove this project's generated WordPress tree and active named volumes. |
| `make ps` | Show this Compose project's services. |
| `make php.build` | Pull the selected base and rebuild the PHP image. |
| `make shell` | Open Bash in the PHP container at `/srv/web`. |
| `make nginx-shell` | Open a shell in nginx. |
| `make db-shell` | Open an authenticated MySQL client. |
| `make wp ARGS="plugin list"` | Run WP-CLI inside PHP. |
| `make composer.install` | Install Composer development dependencies inside PHP. |
| `make lint` | Run PHP syntax checks inside PHP. |
| `make test` | Run PHPUnit inside PHP. |
| `make test-e2e` | Start the complete site, then run Playwright on the host. |
| `make logs` | Follow timestamped Docker logs for all services. |
| `make logs SERVICE=nginx` | Follow one service's Docker logs. |
| `make php.log` | Follow the colorized PHP application log. |
| `make php.log.clear` | Truncate PHP and Xdebug application logs inside PHP. |
| `make hosts-check` | Verify native and, under WSL2, Windows hostname mappings. |
| `make hosts-add` | Add missing project-marked hostname mappings. |
| `make hosts-remove` | Remove only mappings managed for this project. |

Install PHP test dependencies without requiring host PHP:

```bash
make composer.install
make lint
make test
```

## PHP application logs

PHP writes errors to `/var/log/php/error.log` in the project-scoped `php-logs` named volume. The custom PHP image contains `grcat` and the PHP-specific color rules taken from the `wp-server` reference.

Follow the last 50 lines and continue streaming:

```bash
make php.log
```

The target starts MySQL and PHP first, then runs this pipeline inside PHP:

```bash
tail -n 50 -F /var/log/php/error.log | PYTHONUNBUFFERED=1 grcat /home/wodby/.grc/grc.php.log.conf
```

`display_errors`, startup errors, and `E_ALL` reporting are enabled for local development. Docker service logs use bounded `json-file` rotation (`10m` and three files by default). Change `DOCKER_LOG_MAX_SIZE` or `DOCKER_LOG_MAX_FILE` in `.env` if needed.

## Paths and persisted data

The only web document root in both nginx and PHP is `/srv/web`; `/var/www/html` is not used. The generated `local-dev/` directory is mounted there. The repository is separately mounted at `/workspace` so tests and Composer operate on canonical sources without making the repository itself web-accessible.

Setup creates these links inside the generated WordPress tree:

```text
/srv/web/wp-content/plugins/wp-site-options
  -> /workspace/plugin-dir

/srv/web/wp-content/mu-plugins/wp-site-options-fixture.php
  -> /workspace/tests/fixtures/wp-site-options-fixture.php
```

Edits under `plugin-dir/` are therefore visible immediately without copying or rebuilding.

`COMPOSE_PROJECT_NAME` scopes all containers, networks, and named volumes. MySQL data lives in `<project>_mysql-data`, PHP application logs in `<project>_php-logs`, and WordPress files in the ignored `local-dev/` bind mount. `make down` preserves them; only the explicit reset removes the active volumes and generated WordPress files.

The old MariaDB-based local stack used `<project>_db-data`. Upgrading does not delete that volume automatically, so its previous data remains recoverable until deliberately removed.

## Configuration

Common `.env` values are:

- `COMPOSE_PROJECT_NAME` — resource isolation boundary;
- `WP_HOST` — hostname without scheme, port, or path;
- `WP_BIND_ADDRESS` — published interface, `127.0.0.1` by default;
- `WP_HTTP_PORT` — published nginx port;
- `PHP_BASE_IMAGE` — pinned Wodby WordPress PHP base;
- `MYSQL_IMAGE` and `NGINX_IMAGE` — database and web-server images;
- `WP_ADMIN_*` and `DB_*` — local-only credentials;
- `PHP_EXTENSIONS_DISABLE` — optional Wodby extensions disabled at startup.

Legacy `WORDPRESS_IMAGE`, `WP_CLI_IMAGE`, `PHP_IMAGE`, and `DB_IMAGE` variables are ignored. They can be removed from an existing `.env` after comparing it with `.env.example`.

### Running several projects at once

Give every checkout a distinct project name, domain, and HTTP port:

```dotenv
COMPOSE_PROJECT_NAME=wp-site-options-two
WP_HOST=wp-site-options-two.local
WP_HTTP_PORT=8089
```

Run `make setup` in that checkout. It can run beside `wp-site-options.local:8088`; MySQL is internal-only and publishes no host port.

## MySQL TLS and WP-CLI

MySQL 8 automatically provisions a self-signed TLS certificate. The MariaDB client bundled in current Wodby images keeps TLS but disables server-certificate verification for this local connection. WP-CLI 2.12 normally adds `--no-defaults`, so the PHP image supplies command defaults for every `wp db` operation that invokes a client binary. This makes commands such as `db check`, `db export`, and `db reset` consistently load Wodby's TLS client configuration. No local CA setup or per-command SSL flag is required.

## Troubleshooting

### The hostname does not open

Run `make hosts-check`, then `make hosts-add` if needed. Under WSL2 with a Windows browser, both WSL and Windows mappings must pass.

Check service state and the stored URL:

```bash
make ps
make wp ARGS="option get home"
```

### The HTTP port is already allocated

Set another port in `.env`, such as `WP_HTTP_PORT=18088`, and rerun `make setup`.

### A service is unhealthy

Run `make ps` and `make logs`. PHP waits for healthy MySQL, while nginx waits for healthy PHP-FPM. Resolve the first failing dependency and rerun setup.

### Setup refuses to replace a plugin path

Setup repairs symlinks but deliberately refuses to delete a real file or directory at `local-dev/wp-content/plugins/wp-site-options`. Move that path only after confirming it contains no work, then rerun `make setup`.

### Reset behavior

`make reset` asks for the current `COMPOSE_PROJECT_NAME`. For deliberate non-interactive cleanup, use `./scripts/reset-local.sh --yes`. Both forms preserve `.env` and operate only on the selected Compose project.
