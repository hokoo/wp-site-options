#!/usr/bin/env bash

set -Eeuo pipefail

export LC_ALL=C
export TZ=UTC
umask 077

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly project_root="$(cd -- "${script_dir}/.." && pwd)"
readonly deploy_script="${script_dir}/deploy-wordpress-svn.sh"
readonly build_script="${script_dir}/build-release-zip.sh"
readonly assertion_script="${project_root}/tests/svn/assert-repository-state.py"
readonly race_wrapper_source="${project_root}/tests/svn/svn-race-wrapper.sh"
readonly asset_source="${project_root}/.wordpress-org"
readonly release_epoch=1700000000

for command_name in cat chmod cp dirname env grep ln mkdir mktemp python3 rm sed svn svnadmin svnlook tr unzip; do
	command -v "${command_name}" >/dev/null 2>&1 || {
		printf 'SVN deploy fixture test failed: required command not found: %s\n' "${command_name}" >&2
		exit 1
	}
done

[[ -x "${deploy_script}" && -x "${build_script}" ]] || {
	printf 'SVN deploy fixture test failed: deploy/build script is not executable.\n' >&2
	exit 1
}
[[ -f "${assertion_script}" && -x "${race_wrapper_source}" ]] || {
	printf 'SVN deploy fixture test failed: test helper is missing or not executable.\n' >&2
	exit 1
}

readonly work_dir="$(mktemp -d /tmp/wpso-svn-fixtures.XXXXXX)"
cleanup() {
	rm -rf -- "${work_dir}"
}
trap cleanup EXIT

pass_count=0

pass() {
	pass_count=$(( pass_count + 1 ))
	printf 'PASS  %s\n' "$1"
}

fail() {
	printf 'FAIL  %s\n' "$*" >&2
	printf 'SVN deploy fixture suite stopped after %d passed assertions.\n' "${pass_count}" >&2
	exit 1
}

youngest() {
	svnlook youngest "$1"
}

repository_url() {
	printf 'file://%s' "$1"
}

create_repository() {
	local repository_path="$1"
	mkdir -p -- "$(dirname -- "${repository_path}")"
	svnadmin create "${repository_path}"
}

deploy_local() {
	local repository_path="$1"
	shift
	(
		unset WPORG_USERNAME WPORG_PASSWORD
		export SOURCE_DATE_EPOCH="${release_epoch}"
		"${deploy_script}" \
			--zip "${candidate_zip}" \
			--version "${version}" \
			--svn-url "$(repository_url "${repository_path}")" \
			"$@"
	)
}

must_succeed() {
	local label="$1"
	local log_path="$2"
	shift 2
	if "$@" > "${log_path}" 2>&1; then
		return
	fi
	cat "${log_path}" >&2
	fail "${label}: command exited non-zero"
}

assert_output() {
	local label="$1"
	local log_path="$2"
	local expected="$3"
	grep -F -- "${expected}" "${log_path}" >/dev/null || {
		cat "${log_path}" >&2
		fail "${label}: expected output not found: ${expected}"
	}
}

prepare_baseline() {
	local repository_path="$1"
	local label="$2"
	local log_path="${work_dir}/logs/${label}-baseline.log"
	create_repository "${repository_path}"
	must_succeed "${label} baseline" "${log_path}" deploy_local "${repository_path}"
	[[ "$(youngest "${repository_path}")" == '1' ]] || fail "${label}: baseline was not one atomic revision"
}

checkout_repository() {
	local repository_path="$1"
	local destination="$2"
	svn checkout --quiet --ignore-externals --non-interactive --no-auth-cache \
		"$(repository_url "${repository_path}")" "${destination}"
}

commit_fixture() {
	local working_copy="$1"
	local message="$2"
	svn commit --quiet --non-interactive --no-auth-cache \
		--message "${message}" "${working_copy}"
}

assert_repository_state() {
	local label="$1"
	local repository_path="$2"
	local checkout_path="${work_dir}/assertions/${label}"
	checkout_repository "${repository_path}" "${checkout_path}"
	python3 "${assertion_script}" \
		"${checkout_path}" "${candidate_root}" "${asset_source}" "${version}" >/dev/null
	pass "${label}: exact roots, trees, bytes, and properties"
}

expect_failure_unchanged() {
	local label="$1"
	local repository_path="$2"
	local expected_diagnostic="$3"
	shift 3
	local before_revision after_revision log_path status
	before_revision="$(youngest "${repository_path}")"
	log_path="${work_dir}/logs/${label}.log"
	set +e
	"$@" > "${log_path}" 2>&1
	status=$?
	set -e
	after_revision="$(youngest "${repository_path}")"

	(( status != 0 )) || {
		cat "${log_path}" >&2
		fail "${label}: unsafe fixture was accepted"
	}
	[[ "${after_revision}" == "${before_revision}" ]] || {
		cat "${log_path}" >&2
		fail "${label}: repository youngest changed ${before_revision} -> ${after_revision}"
	}
	assert_output "${label}" "${log_path}" "${expected_diagnostic}"
	pass "${label}: rejected and youngest remained ${before_revision}"
}

mkdir -p "${work_dir}/repos" "${work_dir}/logs" "${work_dir}/assertions"
cd "${project_root}"

version="$(sed -n 's/^[[:space:]]*Version:[[:space:]]*\([^[:space:]]*\)[[:space:]]*$/\1/p' \
	"${project_root}/plugin-dir/wp-site-options.php" | tr -d '\r')"
[[ "${version}" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || fail 'canonical version is not normalized'

readonly candidate_zip="${work_dir}/wp-site-options.zip"
readonly candidate_parent="${work_dir}/candidate"
must_succeed 'candidate build' "${work_dir}/logs/candidate-build.log" \
	env SOURCE_DATE_EPOCH="${release_epoch}" "${build_script}" "${candidate_zip}"
mkdir -p "${candidate_parent}"
unzip -q "${candidate_zip}" -d "${candidate_parent}"
readonly candidate_root="${candidate_parent}/wp-site-options"
[[ -d "${candidate_root}" ]] || fail 'validated candidate root is missing'
pass 'fixed-epoch candidate built and strictly validated'

# An empty dry run must describe the delta without creating a revision.
dry_repository="${work_dir}/repos/empty-dry-run"
create_repository "${dry_repository}"
dry_log="${work_dir}/logs/empty-dry-run.log"
must_succeed 'empty dry-run' "${dry_log}" deploy_local "${dry_repository}" --dry-run
assert_output 'empty dry-run' "${dry_log}" 'Dry-run complete: repository revision remained 0; no commit attempted.'
[[ "$(youngest "${dry_repository}")" == '0' ]] || fail 'empty dry-run changed repository youngest'
pass 'empty dry-run left revision zero unchanged'

# First deployment must atomically create exact trunk/assets/tag state; the
# identical rerun must exit without credentials or a new revision.
happy_repository="${work_dir}/repos/happy"
create_repository "${happy_repository}"
happy_log="${work_dir}/logs/happy-first.log"
must_succeed 'first deploy without credentials' "${happy_log}" deploy_local "${happy_repository}"
assert_output 'first deploy' "${happy_log}" 'SVN deployment committed safely: version'
[[ "$(youngest "${happy_repository}")" == '1' ]] || fail 'first deploy was not one atomic revision'
pass 'first local deploy used no WPORG credentials and committed one atomic revision'
assert_repository_state 'first-deploy' "${happy_repository}"

rerun_log="${work_dir}/logs/happy-rerun.log"
before_revision="$(youngest "${happy_repository}")"
must_succeed 'identical credential-free rerun' "${rerun_log}" deploy_local "${happy_repository}"
assert_output 'identical rerun' "${rerun_log}" 'No-op: candidate, assets, and tags/'
[[ "$(youngest "${happy_repository}")" == "${before_revision}" ]] || fail 'identical rerun created a revision'
pass 'identical rerun was credential-free and created no revision'
assert_repository_state 'identical-rerun' "${happy_repository}"

# Stale files and missing canonical files in both managed trees exercise SVN
# additions and exact deletions in one reconciliation commit.
stale_repository="${work_dir}/repos/stale"
prepare_baseline "${stale_repository}" 'stale'
stale_wc="${work_dir}/seed/stale"
checkout_repository "${stale_repository}" "${stale_wc}"
svn delete --quiet "${stale_wc}/trunk/inc/index.php" "${stale_wc}/assets/screenshot-2.png"
printf '<?php // stale fixture\n' > "${stale_wc}/trunk/stale.php"
cp "${asset_source}/screenshot-1.png" "${stale_wc}/assets/stale.png"
svn add --quiet --no-auto-props "${stale_wc}/trunk/stale.php" "${stale_wc}/assets/stale.png"
commit_fixture "${stale_wc}" 'Seed stale managed files'
stale_before="$(youngest "${stale_repository}")"
stale_log="${work_dir}/logs/stale-deploy.log"
must_succeed 'stale reconciliation' "${stale_log}" deploy_local "${stale_repository}"
assert_output 'stale reconciliation' "${stale_log}" 'A- trunk/inc/index.php'
assert_output 'stale reconciliation' "${stale_log}" 'D- trunk/stale.php'
assert_output 'stale reconciliation' "${stale_log}" 'AP assets/screenshot-2.png'
assert_output 'stale reconciliation' "${stale_log}" 'D- assets/stale.png'
[[ "$(youngest "${stale_repository}")" == "$(( stale_before + 1 ))" ]] || fail 'stale reconciliation did not create exactly one revision'
pass 'stale trunk/assets additions and deletions committed exactly once'
assert_repository_state 'stale-reconciled' "${stale_repository}"

# Known transforming properties and wrong MIME values must normalize through a
# property-only commit without content changes.
property_repository="${work_dir}/repos/property-only"
prepare_baseline "${property_repository}" 'property-only'
property_wc="${work_dir}/seed/property-only"
checkout_repository "${property_repository}" "${property_wc}"
svn propset --quiet svn:eol-style LF "${property_wc}/trunk/inc/index.php"
svn propset --quiet svn:keywords Id "${property_wc}/trunk/inc/index.php"
svn propset --quiet svn:executable '*' "${property_wc}/trunk/inc/index.php"
svn propset --quiet svn:externals 'fixture ^/trunk' "${property_wc}/trunk"
svn propset --quiet svn:mime-type application/octet-stream "${property_wc}/assets/screenshot-1.png"
commit_fixture "${property_wc}" 'Seed non-normalized managed properties'
property_before="$(youngest "${property_repository}")"
property_log="${work_dir}/logs/property-deploy.log"
must_succeed 'property-only normalization' "${property_log}" deploy_local "${property_repository}"
assert_output 'property-only normalization' "${property_log}" 'added=0 modified=0 deleted=0 replaced=0 property_modified='
[[ "$(youngest "${property_repository}")" == "$(( property_before + 1 ))" ]] || fail 'property normalization did not create exactly one revision'
pass 'property-only normalization removed transforms and restored MIME policy'
assert_repository_state 'property-normalized' "${property_repository}"

# A byte-different immutable tag must fail before any deploy commit.
different_repository="${work_dir}/repos/different-tag"
prepare_baseline "${different_repository}" 'different-tag'
different_wc="${work_dir}/seed/different-tag"
checkout_repository "${different_repository}" "${different_wc}"
printf '\n// immutable tag conflict\n' >> "${different_wc}/tags/${version}/inc/index.php"
commit_fixture "${different_wc}" 'Seed differing existing tag'
expect_failure_unchanged 'differing-existing-tag' "${different_repository}" \
	"existing tags/${version} differs from candidate: file bytes differ" \
	deploy_local "${different_repository}"

# Unknown properties on otherwise-identical tags are immutable-state failures.
unknown_repository="${work_dir}/repos/unknown-tag-property"
prepare_baseline "${unknown_repository}" 'unknown-tag-property'
unknown_wc="${work_dir}/seed/unknown-tag-property"
checkout_repository "${unknown_repository}" "${unknown_wc}"
svn propset --quiet fixture:unknown unsafe "${unknown_wc}/tags/${version}/inc/index.php"
commit_fixture "${unknown_wc}" 'Seed unknown immutable tag property'
expect_failure_unchanged 'unknown-existing-tag-property' "${unknown_repository}" \
	"existing tags/${version} property policy: properties differ" \
	deploy_local "${unknown_repository}"

# SVN special/symlink entries in a managed tree must be rejected before commit.
symlink_repository="${work_dir}/repos/symlink"
prepare_baseline "${symlink_repository}" 'symlink'
symlink_wc="${work_dir}/seed/symlink"
checkout_repository "${symlink_repository}" "${symlink_wc}"
ln -s index.php "${symlink_wc}/trunk/unsafe-link"
svn add --quiet --no-auto-props "${symlink_wc}/trunk/unsafe-link"
commit_fixture "${symlink_wc}" 'Seed SVN special symlink'
expect_failure_unchanged 'managed-symlink' "${symlink_repository}" \
	"cannot sync candidate to trunk: symlink or special entry" \
	deploy_local "${symlink_repository}"

# svn:externals on an immutable tag is never followed and must fail policy.
externals_repository="${work_dir}/repos/tag-externals"
prepare_baseline "${externals_repository}" 'tag-externals'
externals_wc="${work_dir}/seed/tag-externals"
checkout_repository "${externals_repository}" "${externals_wc}"
svn propset --quiet svn:externals 'fixture ^/trunk' "${externals_wc}/tags/${version}"
commit_fixture "${externals_wc}" 'Seed immutable tag externals'
expect_failure_unchanged 'existing-tag-externals' "${externals_repository}" \
	"existing tags/${version} property policy: properties differ" \
	deploy_local "${externals_repository}"

# The test-only svn wrapper commits a staged remote change immediately before
# the deploy's first --show-updates freshness query. No production hook or eval
# surface is used.
race_repository="${work_dir}/repos/freshness-race"
prepare_baseline "${race_repository}" 'freshness-race'
race_wc="${work_dir}/seed/freshness-race"
checkout_repository "${race_repository}" "${race_wc}"
printf '\n// concurrent fixture revision\n' >> "${race_wc}/trunk/inc/index.php"
race_wrapper_dir="${work_dir}/race-bin"
mkdir -p "${race_wrapper_dir}"
cp "${race_wrapper_source}" "${race_wrapper_dir}/svn"
chmod 0700 "${race_wrapper_dir}/svn"
real_svn="$(command -v svn)"
race_before="$(youngest "${race_repository}")"
race_log="${work_dir}/logs/freshness-race.log"
race_commit_log="${work_dir}/logs/freshness-race-commit.log"
race_sentinel="${work_dir}/freshness-race-triggered"
set +e
(
	unset WPORG_USERNAME WPORG_PASSWORD
	export SOURCE_DATE_EPOCH="${release_epoch}"
	export PATH="${race_wrapper_dir}:${PATH}"
	export WPSO_TEST_REAL_SVN="${real_svn}"
	export WPSO_TEST_RACE_WORKING_COPY="${race_wc}"
	export WPSO_TEST_RACE_SENTINEL="${race_sentinel}"
	export WPSO_TEST_RACE_LOG="${race_commit_log}"
	"${deploy_script}" \
		--zip "${candidate_zip}" \
		--version "${version}" \
		--svn-url "$(repository_url "${race_repository}")"
) > "${race_log}" 2>&1
race_status=$?
set -e
race_after="$(youngest "${race_repository}")"
(( race_status != 0 )) || fail 'freshness race was accepted'
[[ -f "${race_sentinel}" ]] || fail 'freshness race wrapper did not trigger'
[[ "${race_after}" == "$(( race_before + 1 ))" ]] || fail 'race produced a revision count other than its one competing commit'
assert_output 'freshness race' "${race_log}" 'stale SVN working copy: remote delta modified/none at trunk/inc/index.php'
assert_output 'freshness race commit' "${race_commit_log}" "Committed revision ${race_after}."
pass "freshness race rejected deploy after sole competing revision ${race_after}"

printf 'SVN deploy fixture suite: %d passed, 0 failed.\n' "${pass_count}"
