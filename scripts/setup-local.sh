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

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

: "${WP_HOST:=wp-site-options.local}"
: "${WP_HTTP_PORT:=8088}"
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

printf 'Starting the %s Docker Compose stack...\n' "${COMPOSE_PROJECT_NAME:-wp-site-options}"
docker compose up -d --wait

docker compose exec -T --user root wp-cli sh -eu -c '
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
	}

	ensure_link /var/www/html/wp-content/plugins/wp-site-options /srv/web/plugin-dir
	ensure_link /var/www/html/wp-content/mu-plugins/wp-site-options-fixture.php /srv/web/tests/fixtures/wp-site-options-fixture.php
'

if ! docker compose exec -T wp-cli wp core is-installed >/dev/null 2>&1; then
	printf 'Installing WordPress at %s...\n' "${wp_url}"
	docker compose exec -T wp-cli wp core install \
		--url="${wp_url}" \
		--title="${WP_TITLE}" \
		--admin_user="${WP_ADMIN_USER}" \
		--admin_password="${WP_ADMIN_PASSWORD}" \
		--admin_email="${WP_ADMIN_EMAIL}" \
		--skip-email
else
	printf 'WordPress is already installed; preserving its content.\n'
	docker compose exec -T wp-cli wp option update home "${wp_url}" --quiet
	docker compose exec -T wp-cli wp option update siteurl "${wp_url}" --quiet
fi

if ! docker compose exec -T wp-cli wp plugin is-active wp-site-options >/dev/null 2>&1; then
	docker compose exec -T wp-cli wp plugin activate wp-site-options
fi

docker compose exec -T wp-cli wp eval '
	global $wpto;
	if ( ! isset( $wpto->fields["local_fixture"][1]["headline"] ) ) {
		fwrite( STDERR, "Local fixture fields were not registered.\n" );
		exit( 1 );
	}
'

if command -v getent >/dev/null 2>&1 \
	&& getent ahostsv4 "${WP_HOST}" 2>/dev/null \
		| awk '$1 == "127.0.0.1" { found = 1 } END { exit !found }'; then
	printf 'Host %s resolves to 127.0.0.1.\n' "${WP_HOST}"
else
	printf '\nHost mapping not detected. Add this entry before opening the site:\n'
	printf '  127.0.0.1 %s\n' "${WP_HOST}"
	printf 'Use /etc/hosts for a Linux browser, or C:\\Windows\\System32\\drivers\\etc\\hosts for a Windows browser.\n'
fi

printf '\nWordPress is ready: %s\n' "${wp_url}"
