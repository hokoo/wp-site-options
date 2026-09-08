# Local development

The local stack runs an isolated MariaDB, WordPress with Apache, and WP-CLI. By default the site is available at `http://wp-site-options.local:8088`, and the repository is mounted inside the containers at `/srv/web`.

## Prerequisites

- Docker Engine with Docker Compose v2 (`docker compose version`);
- GNU Make;
- PHP 7.4 or newer and Composer for the test and lint targets;
- the PHP DOM, Filter, JSON, libxml, Mbstring, Tokenizer, and XMLWriter extensions required by PHPUnit;
- an available local TCP port (the default is `8088`).

For WSL2, enable Docker Desktop integration for the Linux distribution that contains the checkout. Keep the checkout in the WSL filesystem, for example `/home/<user>/reps/wp-site-options`, rather than under `/mnt/c` or `/mnt/d`. This gives Docker predictable Linux permissions and substantially better bind-mount performance.

On native Linux, ensure the current user can access the Docker daemon before setup. Docker commands should work without changing ownership of repository files.

## First setup

Add the local hostname to the hosts file:

```text
127.0.0.1 wp-site-options.local
```

- When the browser runs on Windows, edit `C:\Windows\System32\drivers\etc\hosts` from an elevated editor.
- When the browser runs on Linux, edit `/etc/hosts` as root.

Then run:

```bash
make setup
```

The setup command creates the ignored `.env` from `.env.example` when necessary, starts the Compose project, installs WordPress, activates WP Site Options, and connects the local fixture. It is safe to run again: existing database content is preserved, the site URL is reconciled with `.env`, and valid symlinks are reused.

The default local credentials are development-only values from `.env.example`. Change them in `.env` when needed; never commit `.env`.

Open `http://wp-site-options.local:8088/wp-admin/` after setup. The setup output reports the exact URL if `WP_HTTP_PORT` has been changed.

## Commands

| Command | Purpose |
| --- | --- |
| `make help` | List the available development commands. |
| `make setup` | Create/configure the complete local site idempotently. |
| `make up` | Start the existing stack and wait for healthy services. |
| `make down` | Stop containers while preserving the database volume and `local-dev/`. |
| `make reset` | Interactively remove this Compose project's containers, network, database volume, and `local-dev/`. |
| `make logs` | Follow the last 100 log lines from all services. |
| `make shell` | Open a shell in the running WP-CLI container. |
| `make lint` | Run the PHP syntax check through Composer. |
| `make test` | Run the unit test suite through Composer. |

Install development dependencies before the quality commands:

```bash
composer install
make lint
make test
```

On Debian/Ubuntu, the additional PHPUnit extensions are commonly provided by the `php-xml` and `php-mbstring` packages matching the selected PHP version.

`make reset` is intentionally destructive and asks for the current `COMPOSE_PROJECT_NAME` before proceeding. For deliberate non-interactive cleanup, use `./scripts/reset-local.sh --yes`. Both forms read `.env` and operate only on that Compose project. The `.env` file itself is preserved.

## Project scope and persisted data

`COMPOSE_PROJECT_NAME` in `.env` scopes container, network, and volume names. The database is stored in the named volume `<project>_db-data`; WordPress files are stored in the ignored `local-dev/` bind mount.

A normal `make down` followed by `make up` preserves both stores. Only the explicit reset removes the database volume and generated WordPress files. If the project name must change, run the reset while `.env` still contains the old name; otherwise the old project's resources remain intentionally untouched.

## Plugin and fixture symlinks

The canonical plugin source is never copied into WordPress. Setup creates these links inside the shared container mounts:

```text
/var/www/html/wp-content/plugins/wp-site-options
  -> /srv/web/plugin-dir

/var/www/html/wp-content/mu-plugins/wp-site-options-fixture.php
  -> /srv/web/tests/fixtures/wp-site-options-fixture.php
```

Therefore an edit under `plugin-dir/` is immediately visible to WordPress without sync or rebuild. The absolute `/srv/web/...` targets are container paths; the links are not expected to resolve when inspected directly from Windows.

Verify the plugin link from the running stack with:

```bash
docker compose exec -T wp-cli readlink /var/www/html/wp-content/plugins/wp-site-options
docker compose exec -T wp-cli wp plugin is-active wp-site-options
```

## Configuration

The commonly changed `.env` values are:

- `COMPOSE_PROJECT_NAME` — isolation boundary for Docker resources;
- `WP_HOST` — hostname without scheme or port;
- `WP_BIND_ADDRESS` — host interface, `127.0.0.1` by default;
- `WP_HTTP_PORT` — published HTTP port, `8088` by default;
- `WORDPRESS_IMAGE` and `WP_CLI_IMAGE` — WordPress/PHP profile;
- `DB_IMAGE` — database profile;
- `WP_ADMIN_*` and `DB_*` — local-only credentials.

After changing the hostname or port, run `make setup` so the WordPress `home` and `siteurl` values match the new URL. Changing `COMPOSE_PROJECT_NAME` selects a different isolated stack rather than renaming existing resources.

## Troubleshooting

### The hostname does not open

Confirm that the hosts entry is in the operating system where the browser runs. In WSL2 with a Windows browser, changing only WSL's `/etc/hosts` is not sufficient. The `.local` suffix can also be claimed by multicast DNS, so keep the explicit `127.0.0.1` mapping.

Check the configured URL and service state:

```bash
docker compose exec -T wp-cli wp option get home
docker compose ps
```

### The HTTP port is already allocated

Set another unused port in `.env`, for example:

```dotenv
WP_HTTP_PORT=18088
```

Run `make setup` again and use the URL printed by the script. Ports `80` and `443` are not required by this stack.

### A service is unhealthy or setup stops

Inspect `docker compose ps` and run `make logs`. The WordPress and WP-CLI services wait for a healthy database, so a database error should be resolved before retrying `make setup`.

### Docker reports permission denied

On WSL2, verify that Docker Desktop is running and integration is enabled for the current distribution. On Linux, ensure the user has permission to access the Docker daemon, then start a new login session after changing group membership.

Do not recursively change ownership of the repository to work around container permissions. Generated WordPress files can be owned by the container user; `make reset` removes them from inside a container for that reason.

### Setup refuses to replace the plugin path

Setup only repairs absent or incorrect symlinks. It deliberately refuses to delete a real file or directory at `local-dev/wp-content/plugins/wp-site-options`. Move that path out of the way after confirming it contains no work, then rerun `make setup`.
