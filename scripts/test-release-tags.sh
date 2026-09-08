#!/usr/bin/env bash

set -Eeuo pipefail

export LC_ALL=C

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly parser="${script_dir}/parse-release-tag.sh"
readonly publisher="${script_dir}/publish-github-release.sh"
readonly ref_verifier="${script_dir}/verify-release-ref.sh"

fail() {
	printf 'Release tag parser suite failed: %s\n' "$*" >&2
	exit 1
}

pass_count=0

assert_valid() {
	local tag="$1"
	local package_version="$2"
	local release_version="$3"
	local release_kind="$4"
	local is_prerelease="$5"
	local output

	output="$("${parser}" "${tag}")" || fail "valid tag rejected: ${tag}"
	grep -Fx "tag=${tag}" <<< "${output}" >/dev/null || fail "tag output differs: ${tag}"
	grep -Fx "package_version=${package_version}" <<< "${output}" >/dev/null || fail "package version differs: ${tag}"
	grep -Fx "release_version=${release_version}" <<< "${output}" >/dev/null || fail "release version differs: ${tag}"
	grep -Fx "release_kind=${release_kind}" <<< "${output}" >/dev/null || fail "release kind differs: ${tag}"
	grep -Fx "is_prerelease=${is_prerelease}" <<< "${output}" >/dev/null || fail "prerelease flag differs: ${tag}"
	pass_count=$(( pass_count + 1 ))
}

assert_invalid() {
	local tag="$1"
	if "${parser}" "${tag}" >/dev/null 2>&1; then
		fail "invalid tag accepted: ${tag}"
	fi
	pass_count=$(( pass_count + 1 ))
}

assert_cli_rejected() {
	local expected_message="$1"
	shift
	local output
	if output="$("$@" 2>&1)"; then
		fail "invalid CLI invocation accepted: $*"
	fi
	grep -F "${expected_message}" <<< "${output}" >/dev/null || fail "CLI rejection message differs: $*"
	pass_count=$(( pass_count + 1 ))
}

assert_valid 'v0.0.0' '0.0.0' '0.0.0' production false
assert_valid 'v1.2.2' '1.2.2' '1.2.2' production false
assert_valid 'v-1.2.2' '1.2.2' '1.2.2' production false
assert_valid 'v10.20.300' '10.20.300' '10.20.300' production false
assert_valid 'v1.2.3-beta.1' '1.2.3' '1.2.3-beta.1' prerelease true
assert_valid 'v-1.2.3-beta.1' '1.2.3' '1.2.3-beta.1' prerelease true
assert_valid 'v1.2.3-rc.0' '1.2.3' '1.2.3-rc.0' prerelease true
assert_valid 'v-0.0.0-rc.9' '0.0.0' '0.0.0-rc.9' prerelease true

invalid_tags=(
	'1.2.3'
	'version-1.2.3'
	'v'
	'v1.2'
	'v1.2.3.4'
	'v--1.2.3'
	'v01.2.3'
	'v1.02.3'
	'v1.2.03'
	'v-01.2.3'
	'v1.2.3-alpha.1'
	'v1.2.3-beta'
	'v1.2.3-beta.'
	'v1.2.3-beta.01'
	'v1.2.3-beta.1.extra'
	'v1.2.3-BETA.1'
	'v1.2.3+build.1'
	'v1.2.3-rc.1+build.2'
	'v1.2.3/'
	'v 1.2.3'
)

for invalid_tag in "${invalid_tags[@]}"; do
	assert_invalid "${invalid_tag}"
done
assert_invalid $'v1.2.3\nmalicious'
assert_invalid $'v1.2.3\tmalicious'

output_file="$(mktemp)"
cleanup() {
	rm -f -- "${output_file}"
}
trap cleanup EXIT
"${parser}" 'v-2.4.6-rc.3' --github-output "${output_file}"
grep -Fx 'package_version=2.4.6' "${output_file}" >/dev/null || fail 'GitHub output package version differs'
grep -Fx 'release_version=2.4.6-rc.3' "${output_file}" >/dev/null || fail 'GitHub output release version differs'
grep -Fx 'is_prerelease=true' "${output_file}" >/dev/null || fail 'GitHub output prerelease flag differs'
pass_count=$(( pass_count + 1 ))

assert_cli_rejected 'all required options must be provided' \
	"${publisher}" --tag v1.2.3 --package-version 1.2.3 \
	--zip /missing/wp-site-options.zip --checksum /missing/wp-site-options.zip.sha256 \
	--prerelease false
assert_cli_rejected 'expected commit must be a lowercase 40-character hexadecimal SHA' \
	"${publisher}" --tag v1.2.3 --expected-commit not-a-sha \
	--package-version 1.2.3 --zip /missing/wp-site-options.zip \
	--checksum /missing/wp-site-options.zip.sha256 --prerelease false
assert_cli_rejected 'expected commit must be a lowercase 40-character hexadecimal SHA' \
	"${ref_verifier}" --tag v1.2.3 --expected-commit ABC \
	--repository hokoo/wp-site-options
assert_cli_rejected 'tag parser rejected the release tag' \
	"${ref_verifier}" --tag v1.2.3-alpha.1 \
	--expected-commit 0000000000000000000000000000000000000000 \
	--repository hokoo/wp-site-options

printf 'Release tag parser suite: %d passed, 0 failed.\n' "${pass_count}"
