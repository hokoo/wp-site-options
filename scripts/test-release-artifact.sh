#!/usr/bin/env bash

set -Eeuo pipefail

export LC_ALL=C
export TZ=UTC
umask 077

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly project_root="$(cd -- "${script_dir}/.." && pwd)"
readonly release_epoch=1700000000
readonly fixture_generator="${project_root}/tests/release/generate-malicious-zips.py"

for command_name in awk bash cat cmp env grep mktemp python3 rm sed sha256sum tr; do
	command -v "${command_name}" >/dev/null 2>&1 || {
		printf 'Release artifact test failed: required command not found: %s\n' "${command_name}" >&2
		exit 1
	}
done

[[ -f "${fixture_generator}" ]] || {
	printf 'Release artifact test failed: fixture generator not found: %s\n' "${fixture_generator}" >&2
	exit 1
}

readonly work_dir="$(mktemp -d /tmp/wpso-release-test.XXXXXX)"
cleanup() {
	rm -rf -- "${work_dir}"
}
trap cleanup EXIT

pass_count=0
fail_count=0

pass() {
	pass_count=$(( pass_count + 1 ))
	printf 'PASS  %s\n' "$1"
}

fail_case() {
	fail_count=$(( fail_count + 1 ))
	printf 'FAIL  %s: %s\n' "$1" "$2" >&2
}

run_success() {
	local name="$1"
	shift
	local output status
	set +e
	output="$({ "$@"; } 2>&1)"
	status=$?
	set -e
	if (( status == 0 )); then
		pass "${name}"
	else
		fail_case "${name}" "unexpected exit ${status}"
		printf '%s\n' "${output}" >&2
	fi
}

expect_rejection() {
	local name="$1"
	local archive="$2"
	local expected_version="$3"
	local expected_diagnostic="$4"
	local output status

	set +e
	output="$(SOURCE_DATE_EPOCH="${release_epoch}" \
		"${script_dir}/validate-release-zip.sh" \
		"${archive}" "${expected_version}" 2>&1)"
	status=$?
	set -e

	if (( status == 0 )); then
		fail_case "${name}" 'validator unexpectedly accepted malicious input'
		return
	fi
	if grep -F -- "${expected_diagnostic}" <<< "${output}" >/dev/null; then
		pass "${name}"
	else
		fail_case "${name}" "expected diagnostic not found: ${expected_diagnostic}"
		printf '%s\n' "${output}" >&2
	fi
}

version="$(sed -n 's/^[[:space:]]*Version:[[:space:]]*\([^[:space:]]*\)[[:space:]]*$/\1/p' \
	"${project_root}/plugin-dir/wp-site-options.php" | tr -d '\r')"
if [[ ! "${version}" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
	printf 'Release artifact test failed: canonical version is not normalized: %s\n' "${version:-missing}" >&2
	exit 1
fi

readonly archive_a="${work_dir}/wp-site-options-a.zip"
readonly archive_b="${work_dir}/wp-site-options-b.zip"
readonly fixtures_dir="${work_dir}/malicious"

run_success 'first fixed-epoch build' env SOURCE_DATE_EPOCH="${release_epoch}" \
	"${script_dir}/build-release-zip.sh" "${archive_a}"
run_success 'second fixed-epoch build' env SOURCE_DATE_EPOCH="${release_epoch}" \
	"${script_dir}/build-release-zip.sh" "${archive_b}"

if [[ -f "${archive_a}" && -f "${archive_b}" ]]; then
	if cmp -s -- "${archive_a}" "${archive_b}"; then
		pass 'byte-for-byte reproducibility (cmp)'
	else
		fail_case 'byte-for-byte reproducibility (cmp)' 'archives differ'
	fi

	sha_a="$(sha256sum -- "${archive_a}" | awk '{print $1}')"
	sha_b="$(sha256sum -- "${archive_b}" | awk '{print $1}')"
	if [[ "${sha_a}" == "${sha_b}" ]]; then
		pass 'identical SHA-256 digests'
	else
		fail_case 'identical SHA-256 digests' "${sha_a} != ${sha_b}"
	fi
	printf 'SHA256 %s\n' "${sha_a}"

	run_success 'known-good strict validation' env SOURCE_DATE_EPOCH="${release_epoch}" \
		"${script_dir}/validate-release-zip.sh" "${archive_a}" "${version}"

	if python3 "${fixture_generator}" "${archive_a}" "${fixtures_dir}" > "${work_dir}/generator.log" 2>&1; then
		pass 'malicious fixture generation'
	else
		fail_case 'malicious fixture generation' 'generator exited non-zero'
		cat "${work_dir}/generator.log" >&2
	fi
else
	fail_case 'fixture prerequisites' 'one or both good builds are missing'
fi

if [[ -d "${fixtures_dir}" ]]; then
	expect_rejection 'wrong/outside root' "${fixtures_dir}/wrong-root.zip" "${version}" 'wrong archive root'
	expect_rejection '../ traversal' "${fixtures_dir}/traversal.zip" "${version}" 'unsafe path component'
	expect_rejection 'absolute path' "${fixtures_dir}/absolute-path.zip" "${version}" 'absolute entry path'
	expect_rejection 'backslash path' "${fixtures_dir}/backslash.zip" "${version}" 'backslash in entry path'
	expect_rejection 'newline/control path' "${fixtures_dir}/control-newline.zip" "${version}" 'control character in entry path'
	expect_rejection 'colon/ADS path' "${fixtures_dir}/colon-ads.zip" "${version}" 'colon in entry path'
	expect_rejection 'duplicate entry' "${fixtures_dir}/duplicate.zip" "${version}" 'duplicate or case-colliding entry'
	expect_rejection 'case collision' "${fixtures_dir}/case-collision.zip" "${version}" 'duplicate or case-colliding entry'
	expect_rejection 'symlink entry' "${fixtures_dir}/symlink.zip" "${version}" 'symlink or special entry type'
	expect_rejection 'unsafe executable mode' "${fixtures_dir}/unsafe-mode.zip" "${version}" 'unsafe or non-normalized mode'
	expect_rejection 'directory payload' "${fixtures_dir}/directory-payload.zip" "${version}" 'directory entry must have zero size'
	expect_rejection 'hidden .env' "${fixtures_dir}/hidden-env.zip" "${version}" 'hidden path is not releasable'
	expect_rejection '.svn metadata' "${fixtures_dir}/svn-metadata.zip" "${version}" 'hidden path is not releasable'
	expect_rejection 'tests/development file' "${fixtures_dir}/development-test.zip" "${version}" 'development directory is not releasable'
	expect_rejection 'missing canonical entry' "${fixtures_dir}/missing-entry.zip" "${version}" 'manifest differs from plugin-dir'
	expect_rejection 'unexpected allowlisted entry' "${fixtures_dir}/unexpected-allowlisted-entry.zip" "${version}" 'file size differs from canonical source'
	expect_rejection 'same-size byte mutation' "${fixtures_dir}/same-size-byte-mutation.zip" "${version}" 'file bytes differ from plugin-dir'
	expect_rejection 'unsorted central directory' "${fixtures_dir}/unsorted-entries.zip" "${version}" 'central-directory entries are not sorted'
	expect_rejection 'wrong common timestamp' "${fixtures_dir}/wrong-common-timestamp.zip" "${version}" 'expected UTC'
	expect_rejection 'archive comment' "${fixtures_dir}/archive-comment.zip" "${version}" 'archive comment is not allowed'
	expect_rejection 'entry extra metadata' "${fixtures_dir}/entry-extra.zip" "${version}" 'extra ZIP metadata is not allowed'
	expect_rejection 'entry comment' "${fixtures_dir}/entry-comment.zip" "${version}" 'entry comment is not allowed'

	mismatch_version='1.2.3'
	if [[ "${mismatch_version}" == "${version}" ]]; then
		mismatch_version='1.2.4'
	fi
	expect_rejection "version mismatch ${mismatch_version}" "${archive_a}" \
		"${mismatch_version}" 'plugin header Version'
	expect_rejection "unnormalized v${version}" "${archive_a}" \
		"v${version}" 'expected version must be normalized X.Y.Z'
fi

total_count=$(( pass_count + fail_count ))
printf 'Release artifact suite: %d passed, %d failed, %d total.\n' \
	"${pass_count}" "${fail_count}" "${total_count}"

(( fail_count == 0 ))
