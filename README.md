# WP Site Options

WordPress plugin for declaring theme/site options on the standard **Settings → Reading** screen.

The canonical installable plugin source lives in [`plugin-dir/`](./plugin-dir/). WordPress.org banners, icons, and screenshots live in [`.wordpress-org/`](./.wordpress-org/) and are not included in the plugin ZIP.

## Delivery status

GitHub `master` is the canonical development source. The repository includes a
Docker local environment, automated compatibility and browser tests,
reproducible release archives, and tag-driven GitHub/WordPress.org deployment.
Automated release `1.2.2` is available from
[GitHub](https://github.com/hokoo/wp-site-options/releases/tag/v1.2.2) and the
[WordPress.org Plugin Directory](https://wordpress.org/plugins/wp-site-options/).

See [local development](docs/development.md), the [release runbook](docs/release.md),
and the [execution backlog](docs/execution-backlog.md).

## Local development

The Docker environment works on WSL2, native Linux, and macOS. Run every
`make` command on the host; the Makefile starts the required services and then
executes PHP, Composer, or WP-CLI commands in the appropriate container.

Prerequisites are Docker with Compose v2 and GNU Make. Node.js and npm are
needed only for the Playwright browser test.

### Quick start

```bash
make setup
```

On the first run, setup:

- creates `.env` from `.env.example` when it does not exist;
- adds `wp-site-options.local` to the hosts file;
- builds and starts MySQL, PHP-FPM, and nginx;
- downloads and installs WordPress;
- links and activates the plugin.

Updating the hosts file may require `sudo` on Linux/macOS or a Windows UAC
confirmation when running under WSL2. When setup finishes, open:

```text
http://wp-site-options.local:8088/wp-admin/
```

Rerunning `make setup` is safe: it reconciles the environment while preserving
the installed database and WordPress content.

### What runs where

| Service | Purpose |
| --- | --- |
| `nginx` | Serves the local domain and forwards PHP requests to PHP-FPM. |
| `php` | Wodby WordPress PHP 8.4 image containing PHP-FPM, Composer, WP-CLI, and the PHP log colorizer. |
| `db` | MySQL 8 database; it is available only inside the Compose network. |

WordPress is generated in the ignored host directory `local-dev/`, mounted as
`/srv/web` in nginx and PHP. The repository itself is mounted in PHP as
`/workspace`. The canonical plugin source remains in `plugin-dir/` and setup
links it into `/srv/web/wp-content/plugins/wp-site-options`, so source edits are
visible immediately without rebuilding the image.

The important local-dev files are:

- `docker-compose.yml` — services, networks, mounts, health checks, and ports;
- `.env` — project name, local domain, port, image versions, and local-only credentials;
- `docker/php/` — the PHP 8.4 image, PHP logging, WP-CLI, and colorizer configuration;
- `docker/nginx/` — the nginx virtual-host template;
- `scripts/setup-local.sh` — idempotent WordPress installation and reconciliation;
- `scripts/local-domain.sh` — hosts-file management for Linux, macOS, and WSL2;
- `local-dev/` — generated WordPress files; do not use it as the plugin source.

MySQL data is stored in the project-scoped `mysql-data` named volume, and PHP
application logs are stored in `php-logs`. `make down` preserves both volumes;
`make reset` explicitly removes them and the generated `local-dev/` tree.

### Common commands

```bash
make up                             # Start and health-check the complete stack
make down                           # Stop it without deleting local data
make ps                             # Show service state
make shell                          # Open a shell in the PHP container
make wp ARGS="plugin list"          # Run WP-CLI in the PHP container
make composer.install               # Install PHP development dependencies
make lint                           # Run PHP syntax checks
make test                           # Run PHPUnit
make test-e2e                       # Run the browser smoke test
make logs SERVICE=nginx             # Follow Docker logs for one service
make php.log                        # Follow the colorized PHP error log
make php.log.clear                  # Clear PHP application logs
make hosts-check                    # Check the local-domain mapping
```

To run another checkout at the same time, give it a unique Compose project,
domain, and HTTP port in `.env`, then run `make setup`:

```dotenv
COMPOSE_PROJECT_NAME=wp-site-options-two
WP_HOST=wp-site-options-two.local
WP_HTTP_PORT=8089
```

See the full [local-development guide](docs/development.md) for configuration,
logging details, reset behavior, and troubleshooting.

## Public API

Existing integrations use the global `$wpto` object and its field declarations. Public hooks, option keys, and behavior are treated as compatibility contracts during the maintenance migration.

## License

GPL-2.0-or-later, matching the WordPress.org plugin metadata.
