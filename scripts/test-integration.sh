#!/usr/bin/env bash

set -Eeuo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly project_root="$(cd -- "${script_dir}/.." && pwd)"
readonly compose_file="${project_root}/tests/integration/docker-compose.yml"
readonly artifact_root="${WP_SITE_OPTIONS_IT_ARTIFACTS:-${project_root}/tests/integration/artifacts}"

profile="${1:-all}"

usage() {
	cat <<'USAGE'
Usage: scripts/test-integration.sh [minimum|latest|all]

Environment:
  PLUGIN_ZIP=/absolute/path.zip      Install a built candidate instead of plugin-dir.
  RUN_PLUGIN_CHECK=1                 Run pinned Plugin Check after lifecycle assertions.
  PLUGIN_CHECK_VERSION=1.9.0         Override the pinned Plugin Check version.
  WP_SITE_OPTIONS_IT_ARTIFACTS=path  Override diagnostic artifact directory.
  KEEP_INTEGRATION_ENV=1             Keep this run's uniquely named Docker resources.
USAGE
}

case "${profile}" in
	minimum|latest)
		;;
	all)
		"$0" minimum
		"$0" latest
		exit 0
		;;
	-h|--help)
		usage
		exit 0
		;;
	*)
		usage >&2
		exit 2
		;;
esac

case "${profile}" in
	minimum)
		readonly core_version="${WP_CORE_VERSION:-6.0}"
		readonly cli_image="${WP_CLI_IMAGE:-wordpress:cli-php7.4}"
		readonly expected_wp_prefix="6.0"
		readonly expected_php_prefix="7.4"
		;;
	latest)
		readonly core_version="${WP_CORE_VERSION:-latest}"
		readonly cli_image="${WP_CLI_IMAGE:-wordpress:cli-php8.3}"
		readonly expected_wp_prefix=""
		readonly expected_php_prefix="8.3"
		;;
esac

readonly run_id="${profile}-$(date -u +%Y%m%dT%H%M%SZ)-$$"
readonly compose_project="wposit$(printf '%s' "${profile}" | tr -cd 'a-z0-9')$$"
readonly artifact_dir="${artifact_root}/${run_id}"
readonly command_log="${artifact_dir}/commands.log"

mkdir -p "${artifact_dir}"
: > "${command_log}"

dc() {
	WP_CLI_IMAGE="${cli_image}" docker compose \
		-f "${compose_file}" \
		-p "${compose_project}" \
		"$@"
}

wp_run() {
	dc exec -T wp-cli php -d memory_limit=512M /usr/local/bin/wp \
		--allow-root \
		--path=/var/www/html \
		"$@"
}

run_logged() {
	printf '+ ' | tee -a "${command_log}"
	printf '%q ' "$@" | tee -a "${command_log}"
	printf '\n' | tee -a "${command_log}"
	"$@" 2>&1 | tee -a "${command_log}"
}

collect_diagnostics() {
	set +e
	dc logs --no-color > "${artifact_dir}/compose.log" 2>&1
	dc exec -T wp-cli sh -c \
		'test ! -f /var/www/html/wp-content/debug.log || cat /var/www/html/wp-content/debug.log' \
		> "${artifact_dir}/wp-debug.log" 2>&1
	set -e
}

cleanup() {
	local status="$?"
	set +e
	collect_diagnostics
	if [[ "${KEEP_INTEGRATION_ENV:-0}" != "1" ]]; then
		dc down --volumes --remove-orphans >> "${command_log}" 2>&1
	else
		printf 'Kept Docker project %s for investigation.\n' "${compose_project}" \
			| tee -a "${command_log}"
	fi
	set -e
	if (( status != 0 )); then
		printf 'Integration profile %s failed; diagnostics: %s\n' "${profile}" "${artifact_dir}" >&2
	fi
	return "${status}"
}
trap cleanup EXIT

run_logged dc up -d --wait db wp-cli
run_logged wp_run core download --version="${core_version}" --locale=en_US --force
run_logged wp_run config create \
	--dbname=wordpress \
	--dbuser=wordpress \
	--dbpass=wordpress \
	--dbhost=db:3306 \
	--skip-check \
	--force
run_logged wp_run db check --skip-ssl
run_logged wp_run config set WP_DEBUG true --raw
run_logged wp_run config set WP_DEBUG_LOG true --raw
run_logged wp_run config set WP_DEBUG_DISPLAY false --raw
run_logged wp_run core install \
	--url="http://${compose_project}.test" \
	--title="WP Site Options Integration" \
	--admin_user=admin \
	--admin_password=integration-password \
	--admin_email=admin@example.test \
	--skip-email

run_logged dc exec -T wp-cli sh -eu -c '
	mkdir -p /var/www/html/wp-content/mu-plugins
	ln -s /srv/web/tests/fixtures/wp-site-options-fixture.php \
		/var/www/html/wp-content/mu-plugins/wp-site-options-fixture.php
'

if [[ -n "${PLUGIN_ZIP:-}" ]]; then
	if [[ ! -f "${PLUGIN_ZIP}" ]]; then
		printf 'PLUGIN_ZIP does not exist: %s\n' "${PLUGIN_ZIP}" >&2
		exit 2
	fi
	run_logged dc cp "${PLUGIN_ZIP}" wp-cli:/tmp/wp-site-options-candidate.zip
	run_logged wp_run plugin install /tmp/wp-site-options-candidate.zip --force
else
	run_logged dc exec -T wp-cli ln -s \
		/srv/web/plugin-dir \
		/var/www/html/wp-content/plugins/wp-site-options
fi

run_logged wp_run plugin activate wp-site-options
run_logged wp_run plugin is-active wp-site-options

actual_wp_version="$(wp_run core version)"
actual_php_version="$(dc exec -T wp-cli php -r 'echo PHP_VERSION;')"

if [[ -n "${expected_wp_prefix}" && "${actual_wp_version}" != "${expected_wp_prefix}"* ]]; then
	printf 'Expected WordPress %s.x, got %s.\n' "${expected_wp_prefix}" "${actual_wp_version}" >&2
	exit 1
fi
if [[ "${actual_php_version}" != "${expected_php_prefix}"* ]]; then
	printf 'Expected PHP %s.x, got %s.\n' "${expected_php_prefix}" "${actual_php_version}" >&2
	exit 1
fi

{
	printf 'profile=%s\n' "${profile}"
	printf 'compose_project=%s\n' "${compose_project}"
	printf 'wordpress=%s\n' "${actual_wp_version}"
	printf 'php=%s\n' "${actual_php_version}"
	printf 'wp_cli_image=%s\n' "${cli_image}"
	printf 'plugin_source=%s\n' "${PLUGIN_ZIP:-plugin-dir}"
} > "${artifact_dir}/environment.txt"

printf '+ wp eval-file /srv/web/tests/integration/wp-lifecycle.php\n' | tee -a "${command_log}"
wp_run eval-file /srv/web/tests/integration/wp-lifecycle.php \
	| tee "${artifact_dir}/lifecycle.json" \
	| tee -a "${command_log}"

if [[ "${RUN_PLUGIN_CHECK:-0}" == "1" ]]; then
	readonly plugin_check_version="${PLUGIN_CHECK_VERSION:-1.9.0}"
	run_logged wp_run plugin install plugin-check \
		--version="${plugin_check_version}" \
		--activate \
		--force

	set +e
	wp_run \
		--require=/var/www/html/wp-content/plugins/plugin-check/cli.php \
		plugin check wp-site-options \
		--format=strict-json \
		--mode=update \
		--fields=type,code,message,file,line,column,docs \
		> "${artifact_dir}/plugin-check.json" \
		2> "${artifact_dir}/plugin-check.stderr"
	plugin_check_status="$?"
	set -e

	if ! jq -e 'type == "array" and all(.[]; type == "object")' \
		"${artifact_dir}/plugin-check.json" >/dev/null; then
		printf 'Plugin Check did not return strict JSON; see %s.\n' "${artifact_dir}" >&2
		exit 1
	fi

	plugin_check_errors="$(jq '[.[] | select(.type == "ERROR")] | length' "${artifact_dir}/plugin-check.json")"
	plugin_check_warnings="$(jq '[.[] | select(.type == "WARNING")] | length' "${artifact_dir}/plugin-check.json")"
	printf 'Plugin Check %s: errors=%s warnings=%s (exit=%s)\n' \
		"${plugin_check_version}" \
		"${plugin_check_errors}" \
		"${plugin_check_warnings}" \
		"${plugin_check_status}" \
		| tee -a "${command_log}"

	if (( plugin_check_errors > 0 )); then
		exit 1
	fi
	if (( plugin_check_status != 0 )); then
		exit "${plugin_check_status}"
	fi
fi

collect_diagnostics
if grep -En 'PHP (Fatal error|Parse error)' "${artifact_dir}/wp-debug.log"; then
	printf 'Fatal PHP diagnostics found in %s.\n' "${artifact_dir}/wp-debug.log" >&2
	exit 1
fi

printf 'Integration profile %s passed (WordPress %s, PHP %s). Evidence: %s\n' \
	"${profile}" \
	"${actual_wp_version}" \
	"${actual_php_version}" \
	"${artifact_dir}"
