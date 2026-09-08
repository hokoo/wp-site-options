#!/usr/bin/env bash

set -Eeuo pipefail

export LC_ALL=C
export GIT_TERMINAL_PROMPT=0

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() {
	cat <<'USAGE'
Usage: scripts/verify-release-ref.sh OPTIONS

Required options:
  --tag TAG
  --expected-commit 40_HEX_SHA
  --repository OWNER/REPOSITORY

Optional:
  --check-master  Also fetch current master and require the expected commit to
                  be its ancestor.

The verifier fetches exact refs from the public GitHub HTTPS URL into temporary
dedicated local refs. It never uses a repository write token or stored HTTP
authorization.
USAGE
}

fail() {
	printf 'Release ref verification failed: %s\n' "$*" >&2
	exit 1
}

tag=''
expected_commit=''
repository=''
check_master=false

while (( $# > 0 )); do
	case "$1" in
		--tag|--expected-commit|--repository)
			(( $# >= 2 )) || fail "$1 requires a value"
			case "$1" in
				--tag) [[ -z "${tag}" ]] || fail '--tag may be specified only once'; tag="$2" ;;
				--expected-commit) [[ -z "${expected_commit}" ]] || fail '--expected-commit may be specified only once'; expected_commit="$2" ;;
				--repository) [[ -z "${repository}" ]] || fail '--repository may be specified only once'; repository="$2" ;;
			esac
			shift 2
			;;
		--check-master)
			[[ "${check_master}" == false ]] || fail '--check-master may be specified only once'
			check_master=true
			shift
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

[[ -n "${tag}" && -n "${expected_commit}" && -n "${repository}" ]] || fail 'all required options must be provided'
[[ "${expected_commit}" =~ ^[0-9a-f]{40}$ ]] || fail 'expected commit must be a lowercase 40-character hexadecimal SHA'
[[ "${repository}" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || fail 'repository must be OWNER/REPOSITORY'
[[ "${repository}" != *'..'* && "${repository}" != .* && "${repository}" != */.* ]] || fail 'repository contains an unsafe dot segment'

"${script_dir}/parse-release-tag.sh" "${tag}" >/dev/null || fail 'tag parser rejected the release tag'
command -v git >/dev/null 2>&1 || fail 'required command not found: git'
git rev-parse --git-dir >/dev/null 2>&1 || fail 'current directory is not a Git worktree'

# actions/checkout with persist-credentials:false removes its temporary header.
# Reject any remaining HTTP authorization header rather than sending it to the
# read-only public endpoint. An empty credential.helper disables stored helpers.
if git config --get-regexp '^http\..*\.extraheader$' >/dev/null 2>&1; then
	fail 'stored Git HTTP authorization/header configuration is not allowed'
fi

readonly public_url="https://github.com/${repository}.git"
readonly verification_id="${expected_commit}-$$-${RANDOM}"
readonly tag_ref="refs/wpso-release-verification/${verification_id}/tag"
readonly master_ref="refs/wpso-release-verification/${verification_id}/master"

cleanup() {
	git update-ref -d "${tag_ref}" >/dev/null 2>&1 || true
	git update-ref -d "${master_ref}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

fetch_refspecs=("+refs/tags/${tag}:${tag_ref}")
if [[ "${check_master}" == true ]]; then
	fetch_refspecs+=("+refs/heads/master:${master_ref}")
fi
fetch_depth_args=()
if [[ -f "$(git rev-parse --git-path shallow)" ]]; then
	fetch_depth_args+=(--unshallow)
fi

GIT_ASKPASS=/bin/false SSH_ASKPASS=/bin/false \
	git -c credential.helper= -c core.askPass=/bin/false fetch \
		--atomic --force --no-tags --no-recurse-submodules --no-write-fetch-head \
		"${fetch_depth_args[@]}" "${public_url}" "${fetch_refspecs[@]}" >/dev/null || fail 'could not fetch exact public release refs'

remote_tag_commit="$(git rev-parse --verify "${tag_ref}^{commit}")" || fail 'remote tag does not resolve to a commit'
[[ "${remote_tag_commit}" == "${expected_commit}" ]] || fail 'remote tag no longer resolves to the expected commit'

if [[ "${check_master}" == true ]]; then
	remote_master_commit="$(git rev-parse --verify "${master_ref}^{commit}")" || fail 'remote master does not resolve to a commit'
	git merge-base --is-ancestor "${expected_commit}" "${remote_master_commit}" || fail 'expected commit is no longer an ancestor of current remote master'
	printf 'Verified public release tag %s at %s on current master %s.\n' "${tag}" "${expected_commit}" "${remote_master_commit}"
else
	printf 'Verified public release tag %s at %s.\n' "${tag}" "${expected_commit}"
fi
