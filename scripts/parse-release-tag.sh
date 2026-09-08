#!/usr/bin/env bash

set -Eeuo pipefail

export LC_ALL=C

usage() {
	cat <<'USAGE'
Usage: scripts/parse-release-tag.sh TAG [--github-output PATH]

Accepted production tags:
  vX.Y.Z
  v-X.Y.Z

Accepted prerelease tags:
  vX.Y.Z-beta.N    v-X.Y.Z-beta.N
  vX.Y.Z-rc.N      v-X.Y.Z-rc.N

The package version output is always normalized X.Y.Z. Prerelease channel data
is retained separately for the GitHub Release flag and display version.
USAGE
}

fail() {
	printf 'Release tag parsing failed: %s\n' "$*" >&2
	exit 1
}

if (( $# == 0 )); then
	usage >&2
	exit 2
fi
if [[ "$1" == '-h' || "$1" == '--help' ]]; then
	usage
	exit 0
fi

tag="$1"
shift
github_output=''

while (( $# > 0 )); do
	case "$1" in
		--github-output)
			[[ -z "${github_output}" ]] || fail '--github-output may be specified only once'
			(( $# >= 2 )) || fail '--github-output requires a path'
			github_output="$2"
			shift 2
			;;
		*)
			fail 'unknown argument'
			;;
	esac
done

(( ${#tag} <= 128 )) || fail 'tag is too long'
[[ ! "${tag}" =~ [[:cntrl:]] ]] || fail 'tag contains a control character'

production_pattern='^v-?((0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*))$'
prerelease_pattern='^v-?((0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*))-(beta|rc)\.(0|[1-9][0-9]*)$'

if [[ "${tag}" =~ ${production_pattern} ]]; then
	package_version="${BASH_REMATCH[1]}"
	release_version="${package_version}"
	release_kind='production'
	is_prerelease='false'
	prerelease_channel=''
	prerelease_number=''
elif [[ "${tag}" =~ ${prerelease_pattern} ]]; then
	package_version="${BASH_REMATCH[1]}"
	prerelease_channel="${BASH_REMATCH[5]}"
	prerelease_number="${BASH_REMATCH[6]}"
	release_version="${package_version}-${prerelease_channel}.${prerelease_number}"
	release_kind='prerelease'
	is_prerelease='true'
else
	fail 'tag must match an approved production or beta.N/rc.N format'
fi

output="$({
	printf 'tag=%s\n' "${tag}"
	printf 'package_version=%s\n' "${package_version}"
	printf 'release_version=%s\n' "${release_version}"
	printf 'release_kind=%s\n' "${release_kind}"
	printf 'is_prerelease=%s\n' "${is_prerelease}"
	printf 'prerelease_channel=%s\n' "${prerelease_channel}"
	printf 'prerelease_number=%s\n' "${prerelease_number}"
})"

if [[ -n "${github_output}" ]]; then
	[[ "${github_output}" != *'\'* && ! "${github_output}" =~ [[:cntrl:]] ]] || fail 'GitHub output path contains unsafe characters'
	[[ -f "${github_output}" && ! -L "${github_output}" ]] || fail 'GitHub output path must be an existing regular file'
	printf '%s\n' "${output}" >> "${github_output}"
else
	printf '%s\n' "${output}"
fi
