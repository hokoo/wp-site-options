#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${PROJECT_ROOT}/.env"

cd "${PROJECT_ROOT}"

if [[ ! -f "${ENV_FILE}" ]]; then
	printf 'No .env file found; refusing to guess which Compose project to reset.\n' >&2
	exit 1
fi

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

readonly project_name="${COMPOSE_PROJECT_NAME:-wp-site-options}"

if [[ "${1:-}" != "--yes" ]]; then
	printf 'This removes the %s Compose containers, network, named database volume, and local-dev files.\n' "${project_name}"
	if [[ ! -t 0 ]]; then
		printf 'Run again with --yes to confirm this project-scoped reset.\n' >&2
		exit 1
	fi
	read -r -p "Type '${project_name}' to continue: " confirmation
	if [[ "${confirmation}" != "${project_name}" ]]; then
		printf 'Reset cancelled.\n'
		exit 0
	fi
fi

if [[ -d "${PROJECT_ROOT}/local-dev" ]]; then
	# WordPress image files are owned by the container user. Remove only the
	# contents of this repository's ignored local-dev bind mount.
	docker compose run --rm --no-deps --user root --entrypoint sh wordpress \
		-c 'find /srv/web/local-dev -mindepth 1 -delete'
fi

docker compose down --volumes --remove-orphans

rmdir "${PROJECT_ROOT}/local-dev" 2>/dev/null || true

printf 'Reset complete for Compose project %s. The .env file was preserved.\n' "${project_name}"
