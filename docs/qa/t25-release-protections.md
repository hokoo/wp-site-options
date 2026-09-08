# T25 release runbook and protection evidence

## Result

PASS. The release/recovery runbook is committed on canonical `master`, its
hosted CI baseline passed, and the repository protections were read back from
GitHub after configuration. No release tag, GitHub Release, release artifact
publication, WordPress.org credential use, or SVN commit occurred.

Evidence date: 2026-09-09. Protected baseline commit:
`bbba8cf637cb87c179df2f21045070dcc5ccca8e`.

## Runbook walkthrough

[The release runbook](../release.md) was walked through against the implemented
scripts and workflows. It covers:

- both stable forms, `vX.Y.Z` and `v-X.Y.Z`, and all approved beta/RC forms;
- the version/header/stable-tag/changelog preflight and explicit production
  approval boundary;
- pull-request CI and exact required-check names;
- deterministic candidate generation and immutable artifact handoff;
- safe variable/secret existence checks that output booleans, not values;
- the GitHub Release and WordPress.org publication sequence;
- fresh-source checksum, SVN, installation, settings, and public-API checks;
- recovery for pre-draft failure, partial draft, GitHub/SVN partial success,
  uncertain runner result, differing immutable state, post-release defects,
  and possible credential exposure;
- the prohibition on moving/deleting Git release tags and overwriting SVN tags;
- retirement of the Windows SVN working copy to read-only reference use.

The local walkthrough confirmed that the credential preflight returns `true`
for both required names, `v1.2.2` normalizes to package version `1.2.2` with
`is_prerelease=false`, actionlint passes both workflows, and the repository diff
is whitespace-clean. No credential value was displayed or stored.

Hosted CI run
[`34288851727`](https://github.com/hokoo/wp-site-options/actions/runs/34288851727)
passed all eight jobs for the runbook baseline, including `Release contracts`
and `Release candidate`.

## Enforced `master` protection

The GitHub branch-protection API returned the following effective contract:

- required pull request: enabled;
- required approving reviews: `0`, preserving a single-maintainer path;
- required branch to be up to date: enabled (`strict=true`);
- administrator enforcement: enabled;
- linear history: enabled;
- conversation resolution: enabled;
- force pushes: disabled;
- branch deletion: disabled;
- merge commits: disabled at repository level;
- squash and rebase merges: enabled;
- merged branch auto-deletion: enabled.

All required checks are bound to the GitHub Actions application (`app_id
15368`), rather than accepting a same-named status from any integration:

```text
PHP quality / PHP 7.4
PHP quality / PHP 8.3
WordPress integration / minimum
WordPress integration / latest
Plugin Check
Authenticated admin smoke
Release contracts
Release candidate
```

This evidence change itself is delivered through a protected pull request,
providing an end-to-end check of the configured merge path.

## Immutable release tags and production environment

Repository ruleset `Immutable release tags` (ID `22593590`) is active for
`refs/tags/v*`. It has no bypass actors and applies both `update` and `deletion`
restrictions. Matching release tags can be created, but cannot be retargeted or
deleted through the normal push path.

The `wordpress-org` environment remains restricted to custom tag policies:

```text
v[0-9]*.[0-9]*.[0-9]*
v-[0-9]*.[0-9]*.[0-9]*
```

Those GitHub globs are intentionally coarse. The strict parser and the
production-only job condition remain the semantic boundary: prereleases never
enter the environment job, and malformed tags fail before publication.

Repository variable `WPORG_USERNAME` and repository secret `WPORG_PASSWORD`
remain present; only their names/existence were checked. The workflow references
them exactly once each, only in the final WordPress.org deploy step.

## Remaining boundary

The repository is ready for the controlled first release, but T26 cannot start
without explicit human approval for production tag `1.2.2`. That approval is
intentionally not inferred from approval of the implementation plan.
