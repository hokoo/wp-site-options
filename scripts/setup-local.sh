#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${PROJECT_ROOT}/.env"
readonly ENV_EXAMPLE="${PROJECT_ROOT}/.env.example"

cd "${PROJECT_ROOT}"

if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
	printf 'Docker Compose v2 is required.\n' >&2
	exit 1
fi

if [[ ! -f "${ENV_FILE}" ]]; then
	cp "${ENV_EXAMPLE}" "${ENV_FILE}"
	printf 'Created .env from .env.example.\n'
fi

if grep -Eq '^(WORDPRESS_IMAGE|WP_CLI_IMAGE|PHP_IMAGE|DB_IMAGE)=' "${ENV_FILE}"; then
	printf 'Note: legacy image variables are ignored; use PHP_BASE_IMAGE and MYSQL_IMAGE (see .env.example).\n'
fi

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

: "${WP_HOST:=wp-site-options.local}"
: "${WP_HTTP_PORT:=8088}"
: "${WP_DEBUG:=1}"
: "${WP_TITLE:=WP Site Options Local}"
: "${WP_ADMIN_USER:=admin}"
: "${WP_ADMIN_PASSWORD:?Set WP_ADMIN_PASSWORD in .env}"
: "${WP_ADMIN_EMAIL:?Set WP_ADMIN_EMAIL in .env}"

if [[ ! "${WP_HTTP_PORT}" =~ ^[0-9]+$ ]] || (( WP_HTTP_PORT < 1 || WP_HTTP_PORT > 65535 )); then
	printf 'WP_HTTP_PORT must be an integer from 1 to 65535.\n' >&2
	exit 1
fi

if [[ "${WP_HOST}" == *://* || "${WP_HOST}" == */* || "${WP_HOST}" == *:* ]]; then
	printf 'WP_HOST must contain a hostname only, without a scheme, port, or path.\n' >&2
	exit 1
fi

wp_url="http://${WP_HOST}"
if [[ "${WP_HTTP_PORT}" != "80" ]]; then
	wp_url="${wp_url}:${WP_HTTP_PORT}"
fi
readonly wp_url

mkdir -p "${PROJECT_ROOT}/local-dev"

printf 'Building and starting db + PHP for %s...\n' "${COMPOSE_PROJECT_NAME:-wp-site-options}"
docker compose up -d --build --wait --remove-orphans db php

# The generated WordPress tree is the only document root. The project checkout
# is mounted separately at /workspace so plugin source remains canonical.
docker compose exec -T --user root php sh -eu -c '
	chown -R wodby:wodby /srv/web
	install -d -o wodby -g wodby /srv/web/wp-content
'

docker compose exec -T php sh -eu -c '
	cd /srv/web

	if [ ! -f wp-load.php ]; then
		printf "Downloading WordPress core into /srv/web...\n"
		wp core download --force
	fi

	if [ ! -f wp-config.php ]; then
		printf "Creating wp-config.php...\n"
		wp config create \
			--dbname="${DB_NAME}" \
			--dbuser="${DB_USER}" \
			--dbpass="${DB_PASSWORD}" \
			--dbhost="${DB_HOST}:${DB_PORT}" \
			--dbcharset=utf8mb4 \
			--skip-check
	fi

	wp config set DB_NAME "${DB_NAME}" --type=constant --quiet
	wp config set DB_USER "${DB_USER}" --type=constant --quiet
	wp config set DB_PASSWORD "${DB_PASSWORD}" --type=constant --quiet
	wp config set DB_HOST "${DB_HOST}:${DB_PORT}" --type=constant --quiet

	case "${WP_DEBUG}" in
		1|true|TRUE|yes|YES|on|ON)
			wp config set WP_DEBUG true --raw --type=constant --quiet
			wp config set WP_DEBUG_LOG /var/log/php/error.log --type=constant --quiet
			wp config set WP_DEBUG_DISPLAY true --raw --type=constant --quiet
			;;
		*)
			wp config set WP_DEBUG false --raw --type=constant --quiet
			wp config set WP_DEBUG_DISPLAY false --raw --type=constant --quiet
			;;
	esac
'

docker compose exec -T --user root php sh -eu -c '
	ensure_link() {
		link_path="$1"
		target_path="$2"

		mkdir -p "$(dirname "${link_path}")"

		if [ -L "${link_path}" ]; then
			if [ "$(readlink "${link_path}")" = "${target_path}" ]; then
				return
			fi
			rm "${link_path}"
		elif [ -e "${link_path}" ]; then
			printf "Refusing to replace non-symlink path: %s\n" "${link_path}" >&2
			exit 1
		fi

		ln -s "${target_path}" "${link_path}"
		chown -h wodby:wodby "${link_path}"
	}

	ensure_link /srv/web/wp-content/plugins/wp-site-options /workspace/plugin-dir
	ensure_link /srv/web/wp-content/mu-plugins/wp-site-options-fixture.php /workspace/tests/fixtures/wp-site-options-fixture.php
'

if ! docker compose exec -T php wp core is-installed >/dev/null 2>&1; then
	printf 'Installing WordPress at %s...\n' "${wp_url}"
	docker compose exec -T php wp core install \
		--url="${wp_url}" \
		--title="${WP_TITLE}" \
		--admin_user="${WP_ADMIN_USER}" \
		--admin_password="${WP_ADMIN_PASSWORD}" \
		--admin_email="${WP_ADMIN_EMAIL}" \
		--skip-email
else
	printf 'WordPress is already installed; preserving its content.\n'
	docker compose exec -T php wp option update home "${wp_url}" --quiet
	docker compose exec -T php wp option update siteurl "${wp_url}" --quiet
fi

if ! docker compose exec -T php wp plugin is-active wp-site-options >/dev/null 2>&1; then
	docker compose exec -T php wp plugin activate wp-site-options
fi

docker compose exec -T php wp eval '
	global $wpto;
	if ( ! isset( $wpto->fields["local_fixture"][1]["headline"] ) ) {
		fwrite( STDERR, "Local fixture fields were not registered.\n" );
		exit( 1 );
	}
'

printf 'Starting nginx...\n'
docker compose up -d --wait --remove-orphans nginx

if ! "${SCRIPT_DIR}/local-domain.sh" check; then
	printf '\nLocal-domain mapping is incomplete. Run `make hosts-add`, then retry.\n' >&2
fi

printf '\nWordPress is ready: %s\n' "${wp_url}"
