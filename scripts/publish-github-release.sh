#!/usr/bin/env bash

set -Eeuo pipefail

export LC_ALL=C
umask 077

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() {
	cat <<'USAGE'
Usage: scripts/publish-github-release.sh OPTIONS

Required options:
  --tag TAG
  --expected-commit 40_HEX_SHA
  --package-version X.Y.Z
  --zip PATH
  --checksum PATH
  --prerelease true|false

GITHUB_REPOSITORY must identify owner/repository and GH_TOKEN must grant
contents:write. Existing assets are never deleted, replaced, or clobbered.
USAGE
}

fail() {
	printf 'GitHub Release publication failed: %s\n' "$*" >&2
	exit 1
}

tag=''
expected_commit=''
package_version=''
zip_path=''
checksum_path=''
is_prerelease=''

while (( $# > 0 )); do
	case "$1" in
		--tag|--expected-commit|--package-version|--zip|--checksum|--prerelease)
			(( $# >= 2 )) || fail "$1 requires a value"
			case "$1" in
				--tag) [[ -z "${tag}" ]] || fail '--tag may be specified only once'; tag="$2" ;;
				--expected-commit) [[ -z "${expected_commit}" ]] || fail '--expected-commit may be specified only once'; expected_commit="$2" ;;
				--package-version) [[ -z "${package_version}" ]] || fail '--package-version may be specified only once'; package_version="$2" ;;
				--zip) [[ -z "${zip_path}" ]] || fail '--zip may be specified only once'; zip_path="$2" ;;
				--checksum) [[ -z "${checksum_path}" ]] || fail '--checksum may be specified only once'; checksum_path="$2" ;;
				--prerelease) [[ -z "${is_prerelease}" ]] || fail '--prerelease may be specified only once'; is_prerelease="$2" ;;
			esac
			shift 2
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			fail 'unknown argument'
			;;
	esac
done

[[ -n "${tag}" && -n "${expected_commit}" && -n "${package_version}" && -n "${zip_path}" && -n "${checksum_path}" && -n "${is_prerelease}" ]] || fail 'all required options must be provided'
[[ "${expected_commit}" =~ ^[0-9a-f]{40}$ ]] || fail 'expected commit must be a lowercase 40-character hexadecimal SHA'
[[ "${package_version}" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || fail 'package version must be normalized X.Y.Z'
[[ "${is_prerelease}" == true || "${is_prerelease}" == false ]] || fail '--prerelease must be true or false'

for command_name in awk basename cmp gh mktemp python3 realpath sed sha256sum wc; do
	command -v "${command_name}" >/dev/null 2>&1 || fail "required command not found: ${command_name}"
done

repository="${GITHUB_REPOSITORY:-}"
[[ "${repository}" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || fail 'GITHUB_REPOSITORY is invalid'
[[ -n "${GH_TOKEN:-}" && ! "${GH_TOKEN}" =~ [[:cntrl:]] ]] || fail 'GH_TOKEN is missing or contains a control character'

parsed_tag="$("${script_dir}/parse-release-tag.sh" "${tag}")" || fail 'tag parser rejected the release tag'
parsed_package="$(sed -n 's/^package_version=//p' <<< "${parsed_tag}")"
parsed_release_version="$(sed -n 's/^release_version=//p' <<< "${parsed_tag}")"
parsed_prerelease="$(sed -n 's/^is_prerelease=//p' <<< "${parsed_tag}")"
[[ "${parsed_package}" == "${package_version}" ]] || fail 'tag package version differs from requested package version'
[[ "${parsed_prerelease}" == "${is_prerelease}" ]] || fail 'tag prerelease kind differs from requested release kind'

[[ -f "${zip_path}" && ! -L "${zip_path}" ]] || fail 'ZIP must be a regular non-symlink file'
[[ -f "${checksum_path}" && ! -L "${checksum_path}" ]] || fail 'checksum must be a regular non-symlink file'
zip_path="$(realpath -- "${zip_path}")"
checksum_path="$(realpath -- "${checksum_path}")"
[[ "$(basename -- "${zip_path}")" == 'wp-site-options.zip' ]] || fail 'ZIP basename must be wp-site-options.zip'
[[ "$(basename -- "${checksum_path}")" == 'wp-site-options.zip.sha256' ]] || fail 'checksum basename must be wp-site-options.zip.sha256'

expected_sha="$(sed -n 's/^\([0-9a-f]\{64\}\)  wp-site-options\.zip$/\1/p' "${checksum_path}")"
[[ "${expected_sha}" =~ ^[0-9a-f]{64}$ && "$(wc -l < "${checksum_path}")" == 1 ]] || fail 'checksum file must contain one normalized inner ZIP digest'
actual_sha="$(sha256sum "${zip_path}" | awk '{ print $1 }')"
[[ "${actual_sha}" == "${expected_sha}" ]] || fail 'local ZIP does not match checksum file'

verify_remote_source() {
	"${script_dir}/verify-release-ref.sh" \
		--tag "${tag}" \
		--expected-commit "${expected_commit}" \
		--repository "${repository}" \
		--check-master >/dev/null
}

# This is deliberately before the first command that can mutate a Release.
verify_remote_source

work_dir="$(mktemp -d)"
cleanup() {
	rm -rf -- "${work_dir}"
}
trap cleanup EXIT

release_json="${work_dir}/release.json"
release_error="${work_dir}/release-error.log"
created_release=false
if ! gh release view "${tag}" --repo "${repository}" \
	--json tagName,isDraft,isPrerelease,assets,url > "${release_json}" 2> "${release_error}"; then
	create_args=(
		release create "${tag}"
		--repo "${repository}"
		--verify-tag
		--draft
		--generate-notes
		--title "WP Site Options ${parsed_release_version}"
	)
	if [[ "${is_prerelease}" == true ]]; then
		create_args+=(--prerelease --latest=false)
	fi
	gh "${create_args[@]}" >/dev/null || fail 'could not create draft GitHub Release'
	created_release=true
	gh release view "${tag}" --repo "${repository}" \
		--json tagName,isDraft,isPrerelease,assets,url > "${release_json}" || fail 'could not inspect created draft release'
fi

inspect_release() {
	local expected_state="$1"
	local asset_policy="$2"
	python3 - "${release_json}" "${tag}" "${is_prerelease}" "${repository}" "${expected_state}" "${asset_policy}" <<'PY'
import json
import re
import sys

json_path, tag, prerelease, repository, expected_state, asset_policy = sys.argv[1:]
with open(json_path, encoding="utf-8") as release_file:
    release = json.load(release_file)

if release.get("tagName") != tag:
    raise SystemExit("GitHub Release publication failed: release tag differs")
if release.get("isPrerelease") is not (prerelease == "true"):
    raise SystemExit("GitHub Release publication failed: release prerelease flag differs")
if expected_state == "draft" and release.get("isDraft") is not True:
    raise SystemExit("GitHub Release publication failed: expected a draft release")
if expected_state == "published" and release.get("isDraft") is not False:
    raise SystemExit("GitHub Release publication failed: expected a published release")

assets = release.get("assets")
if not isinstance(assets, list):
    raise SystemExit("GitHub Release publication failed: release assets are unavailable")
names = [asset.get("name") for asset in assets if isinstance(asset, dict)]
if len(names) != len(set(names)):
    raise SystemExit("GitHub Release publication failed: duplicate release asset names")
allowed = {"wp-site-options.zip", "wp-site-options.zip.sha256"}
if not set(names).issubset(allowed):
    raise SystemExit("GitHub Release publication failed: unexpected release asset")
if asset_policy == "exact" and set(names) != allowed:
    raise SystemExit("GitHub Release publication failed: published asset set is incomplete")

url = release.get("url", "")
url_pattern = r"^https://github\.com/" + re.escape(repository) + r"/releases/tag/[A-Za-z0-9._-]+$"
if not re.fullmatch(url_pattern, url):
    raise SystemExit("GitHub Release publication failed: release URL is invalid")

print("has_zip=" + ("true" if "wp-site-options.zip" in names else "false"))
print("has_checksum=" + ("true" if "wp-site-options.zip.sha256" in names else "false"))
PY
}

initial_state="$(python3 -c 'import json,sys; print("draft" if json.load(open(sys.argv[1], encoding="utf-8"))["isDraft"] else "published")' "${release_json}")"
[[ "${initial_state}" == draft || "${initial_state}" == published ]] || fail 'release state is invalid'
asset_policy='subset'
if [[ "${initial_state}" == published ]]; then
	asset_policy='exact'
fi
state_output="$(inspect_release "${initial_state}" "${asset_policy}")"
has_zip="$(sed -n 's/^has_zip=//p' <<< "${state_output}")"
has_checksum="$(sed -n 's/^has_checksum=//p' <<< "${state_output}")"

existing_dir="${work_dir}/existing"
mkdir "${existing_dir}"
if [[ "${has_zip}" == true ]]; then
	gh release download "${tag}" --repo "${repository}" --pattern 'wp-site-options.zip' --dir "${existing_dir}" >/dev/null || fail 'could not download existing release ZIP'
	cmp "${zip_path}" "${existing_dir}/wp-site-options.zip" || fail 'existing release ZIP bytes differ'
elif [[ "${initial_state}" == draft ]]; then
	gh release upload "${tag}" "${zip_path}" --repo "${repository}" >/dev/null || fail 'could not upload release ZIP'
else
	fail 'published release ZIP is missing'
fi

if [[ "${has_checksum}" == true ]]; then
	gh release download "${tag}" --repo "${repository}" --pattern 'wp-site-options.zip.sha256' --dir "${existing_dir}" >/dev/null || fail 'could not download existing release checksum'
	cmp "${checksum_path}" "${existing_dir}/wp-site-options.zip.sha256" || fail 'existing release checksum bytes differ'
elif [[ "${initial_state}" == draft ]]; then
	gh release upload "${tag}" "${checksum_path}" --repo "${repository}" >/dev/null || fail 'could not upload release checksum'
else
	fail 'published release checksum is missing'
fi

gh release view "${tag}" --repo "${repository}" \
	--json tagName,isDraft,isPrerelease,assets,url > "${release_json}" || fail 'could not inspect uploaded release assets'
inspect_release "${initial_state}" exact >/dev/null

service_dir="${work_dir}/service-copy"
mkdir "${service_dir}"
gh release download "${tag}" --repo "${repository}" \
	--pattern 'wp-site-options.zip' --pattern 'wp-site-options.zip.sha256' \
	--dir "${service_dir}" >/dev/null || fail 'could not download complete release assets'
cmp "${zip_path}" "${service_dir}/wp-site-options.zip" || fail 'service ZIP differs from verified candidate'
cmp "${checksum_path}" "${service_dir}/wp-site-options.zip.sha256" || fail 'service checksum differs from verified checksum'
(
	cd "${service_dir}"
	sha256sum -c wp-site-options.zip.sha256 >/dev/null
) || fail 'service ZIP fails its inner checksum'

if [[ "${initial_state}" == draft ]]; then
	# A moved/deleted tag or rewritten master leaves the verified assets in a
	# safe draft rather than publishing from stale source authority.
	verify_remote_source
	gh release edit "${tag}" --repo "${repository}" --draft=false >/dev/null || fail 'could not publish verified draft release'
fi

gh release view "${tag}" --repo "${repository}" \
	--json tagName,isDraft,isPrerelease,assets,url > "${release_json}" || fail 'could not inspect published release'
inspect_release published exact >/dev/null
verify_remote_source

if [[ "${created_release}" == true ]]; then
	printf 'Published verified GitHub Release %s (%s).\n' "${tag}" "${expected_sha}"
else
	printf 'Verified idempotent GitHub Release %s (%s).\n' "${tag}" "${expected_sha}"
fi
