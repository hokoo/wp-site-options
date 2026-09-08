#!/usr/bin/env bash

set -Eeuo pipefail

export LC_ALL=C
export TZ=UTC
umask 022

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly project_root="$(cd -- "${script_dir}/.." && pwd)"
readonly source_dir="${project_root}/plugin-dir"

usage() {
	cat <<'USAGE'
Usage: scripts/build-release-zip.sh [output.zip]

Builds an installable deterministic ZIP from the canonical plugin-dir only.
SOURCE_DATE_EPOCH may override the default epoch of the checked-out HEAD commit.
USAGE
}

fail() {
	printf 'Release ZIP build failed: %s\n' "$*" >&2
	exit 1
}

if (( $# > 1 )); then
	usage >&2
	exit 2
fi
if [[ "${1:-}" == '-h' || "${1:-}" == '--help' ]]; then
	usage
	exit 0
fi

for command_name in git zip unzip python3 find sort touch chmod cp realpath mktemp; do
	command -v "${command_name}" >/dev/null 2>&1 || fail "required command not found: ${command_name}"
done

cd "${project_root}"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail 'project root is not a Git worktree'
[[ -d "${source_dir}" && ! -L "${source_dir}" ]] || fail 'plugin-dir must be a real directory'
[[ -f "${source_dir}/wp-site-options.php" ]] || fail 'plugin entrypoint is missing'
[[ -f "${source_dir}/readme.txt" ]] || fail 'WordPress.org readme is missing'

source_status="$(git status --porcelain=v1 --untracked-files=all -- plugin-dir)"
[[ -z "${source_status}" ]] || fail "plugin-dir is dirty; commit or remove source changes first:"$'\n'"${source_status}"

validate_release_path() {
	local relative_path="$1"
	local path_kind="$2"
	local lower_path component basename

	[[ -n "${relative_path}" ]] || fail 'empty source path'
	[[ "${relative_path}" != *'\\'* ]] || fail "backslash is not allowed in source path: ${relative_path}"
	[[ "${relative_path}" != *:* ]] || fail "colon is not allowed in source path: ${relative_path}"
	[[ ! "${relative_path}" =~ [[:cntrl:]] ]] || fail "control character is not allowed in source path: ${relative_path}"

	lower_path="${relative_path,,}"
	IFS='/' read -r -a components <<< "${lower_path}"
	for component in "${components[@]}"; do
		[[ -n "${component}" && "${component}" != '.' && "${component}" != '..' ]] || fail "unsafe source path: ${relative_path}"
		[[ "${component}" != .* ]] || fail "hidden source path is not releasable: ${relative_path}"
		case "${component}" in
			vendor|node_modules|tests|test|docs|doc|coverage|dist|local-dev|playwright-report|test-results)
				fail "development directory is not releasable: ${relative_path}"
				;;
		esac
	done

	if [[ "${path_kind}" != 'file' ]]; then
		return
	fi

	basename="${lower_path##*/}"
	case "${basename}" in
		composer.json|composer.lock|package.json|package-lock.json|npm-shrinkwrap.json|yarn.lock|pnpm-lock.yaml|phpunit*|phpcs*|dockerfile*|docker-compose*|compose.yml|compose.yaml|makefile|readme.md|*.dist|*.example)
			fail "development file is not releasable: ${relative_path}"
			;;
		*secret*|*credential*|id_rsa*|id_dsa*|id_ecdsa*|id_ed25519*)
			fail "secret-like file name is not releasable: ${relative_path}"
			;;
	esac

	case "${basename}" in
		*.php|*.txt|*.css|*.js|*.json|*.xml|*.po|*.mo|*.pot|*.png|*.jpg|*.jpeg|*.gif|*.svg|*.webp|*.avif|*.ico|*.woff|*.woff2|*.ttf|*.eot|license|copying|notice)
			;;
		*)
			fail "disallowed release file type: ${relative_path}"
			;;
	esac
}

while IFS= read -r -d '' source_path; do
	relative_path="${source_path#${source_dir}/}"
	if [[ -d "${source_path}" && ! -L "${source_path}" ]]; then
		validate_release_path "${relative_path}" directory
		[[ -n "$(git ls-files -- "plugin-dir/${relative_path}")" ]] || fail "untracked or empty source directory: ${relative_path}"
	elif [[ -f "${source_path}" && ! -L "${source_path}" ]]; then
		validate_release_path "${relative_path}" file
		git_record="$(git ls-files -s -- "plugin-dir/${relative_path}")"
		[[ -n "${git_record}" ]] || fail "source file is not tracked by Git: ${relative_path}"
		[[ "${git_record%% *}" == '100644' ]] || fail "source file must have Git mode 100644: ${relative_path}"
	else
		fail "symlink or special source entry is not releasable: ${relative_path}"
	fi
done < <(find "${source_dir}" -mindepth 1 -print0)

if [[ -n "${SOURCE_DATE_EPOCH:-}" ]]; then
	release_epoch="${SOURCE_DATE_EPOCH}"
else
	release_epoch="$(git show -s --format=%ct HEAD)"
fi
[[ "${release_epoch}" =~ ^[0-9]+$ ]] || fail 'SOURCE_DATE_EPOCH must be an integer Unix timestamp'
(( release_epoch >= 315532800 && release_epoch <= 4354819198 )) || fail 'SOURCE_DATE_EPOCH must fit the ZIP timestamp range 1980-2107'
release_epoch="$(( release_epoch - ( release_epoch % 2 ) ))"

version="$(sed -n 's/^[[:space:]]*Version:[[:space:]]*\([^[:space:]]*\)[[:space:]]*$/\1/p' "${source_dir}/wp-site-options.php" | tr -d '\r')"
[[ "${version}" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || fail "plugin header Version is not normalized X.Y.Z: ${version:-missing}"

requested_output_path="${1:-${project_root}/dist/wp-site-options.zip}"
if [[ "${requested_output_path}" != /* ]]; then
	requested_output_path="${project_root}/${requested_output_path}"
fi
output_path="$(python3 -c 'import os, sys; print(os.path.abspath(sys.argv[1]))' "${requested_output_path}")"
case "${output_path}" in
	"${source_dir}"|"${source_dir}"/*)
		fail 'output ZIP cannot be placed inside plugin-dir'
		;;
esac

output_dir="$(dirname -- "${output_path}")"
current_path='/'
IFS='/' read -r -a output_components <<< "${output_dir#/}"
for component in "${output_components[@]}"; do
	[[ -n "${component}" ]] || continue
	current_path="${current_path%/}/${component}"
	if [[ -e "${current_path}" || -L "${current_path}" ]]; then
		[[ ! -L "${current_path}" ]] || fail "output parent cannot contain a symlink: ${current_path}"
		[[ -d "${current_path}" ]] || fail "output parent component is not a directory: ${current_path}"
	else
		mkdir -- "${current_path}"
	fi
done
[[ ! -L "${output_path}" ]] || fail "refusing to replace symlink output: ${output_path}"
[[ ! -e "${output_path}" || -f "${output_path}" ]] || fail "output path is not a regular file: ${output_path}"

work_dir="$(mktemp -d "${output_dir}/.wpso-release.XXXXXX")"
cleanup() {
	rm -rf -- "${work_dir}"
}
trap cleanup EXIT

stage_root="${work_dir}/wp-site-options"
mkdir -p "${stage_root}"
cp -a "${source_dir}/." "${stage_root}/"
find "${stage_root}" -type d -exec chmod 0755 {} +
find "${stage_root}" -type f -exec chmod 0644 {} +
find "${stage_root}" -exec touch -h -d "@${release_epoch}" {} +

entry_list="${work_dir}/entries.txt"
(
	cd "${work_dir}"
	find wp-site-options -print | sort > "${entry_list}"
	zip -X -q "${work_dir}/wp-site-options.zip" -@ < "${entry_list}"
)

"${script_dir}/validate-release-zip.sh" "${work_dir}/wp-site-options.zip" "${version}"
mv -f -- "${work_dir}/wp-site-options.zip" "${output_path}"
printf 'Built deterministic release ZIP: %s (version %s, SOURCE_DATE_EPOCH=%s)\n' "${output_path}" "${version}" "${release_epoch}"
