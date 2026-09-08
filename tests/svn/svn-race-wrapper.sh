#!/usr/bin/env bash

set -Eeuo pipefail

real_svn="${WPSO_TEST_REAL_SVN:-}"
race_working_copy="${WPSO_TEST_RACE_WORKING_COPY:-}"
race_sentinel="${WPSO_TEST_RACE_SENTINEL:-}"
race_log="${WPSO_TEST_RACE_LOG:-}"

[[ "${real_svn}" == /* && -x "${real_svn}" ]] || {
	printf 'SVN race wrapper: invalid real svn path.\n' >&2
	exit 97
}

trigger=false
for argument in "$@"; do
	if [[ "${argument}" == '--show-updates' ]]; then
		trigger=true
		break
	fi
done

if [[ "${trigger}" == true && -n "${race_working_copy}" && -n "${race_sentinel}" && ! -e "${race_sentinel}" ]]; then
	[[ "${race_working_copy}" == /* && -d "${race_working_copy}/.svn" ]] || exit 98
	[[ "${race_sentinel}" == /* && "${race_log}" == /* ]] || exit 99
	"${real_svn}" commit --non-interactive --no-auth-cache \
		--message 'Fixture concurrent change' "${race_working_copy}" > "${race_log}" 2>&1
	: > "${race_sentinel}"
fi

exec "${real_svn}" "$@"
