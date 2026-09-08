# T26 production release 1.2.2 evidence

## Result

PASS. After explicit owner approval, production tag `v1.2.2` triggered the
complete release workflow. GitHub Release `v1.2.2` and WordPress.org SVN
revision `3687381` were published from the same verified candidate. No tag or
asset was moved, replaced, deleted, or force-updated.

Release date: 2026-09-09 local / 2026-09-08 UTC.

## Source authority

```text
tag: v1.2.2
tag kind: annotated
tag object: f2523b16255c6289fe0e22b698b4a474dea2c7ca
commit: ed1aa25682453c049fe80330019eb4ddadcd0c7d
package version: 1.2.2
```

Immediately before tag creation, local `HEAD`, `origin/master`, and the approved
commit were identical; the worktree was clean. The tag parser returned
`release_kind=production` and `is_prerelease=false`. Plugin header, readme
stable tag, and the single changelog heading all matched `1.2.2`. Neither the
Git tag, GitHub Release, nor WordPress.org `tags/1.2.2` existed before the push.

The repository's active immutable-tag ruleset allows creation but prohibits
subsequent update or deletion of matching `v*` tags.

## GitHub Actions and artifact

Production workflow
[`34290682147`](https://github.com/hokoo/wp-site-options/actions/runs/34290682147)
completed successfully. All eleven jobs passed:

- release intent;
- PHP quality on PHP 7.4 and 8.3;
- WordPress integration on minimum and latest profiles;
- Plugin Check;
- authenticated admin smoke;
- release tag/SVN contracts;
- deterministic artifact build and service round trip;
- GitHub Release publication;
- WordPress.org deployment.

The immutable Actions artifact was ID `10081256307`, named
`wp-site-options-release-ed1aa25682453c049fe80330019eb4ddadcd0c7d-34290682147-1`.
It was created at `2026-09-08T23:28:42Z` with 90-day retention.

[GitHub Release `v1.2.2`](https://github.com/hokoo/wp-site-options/releases/tag/v1.2.2)
was published at `2026-09-08T23:29:01Z`. It is neither draft nor prerelease and
contains exactly two uploaded assets:

```text
wp-site-options.zip
  size: 11577
  sha256: eb031e18e680413524be38cfb533afd438f357b2f1693627f9bbcd92838fb8f9

wp-site-options.zip.sha256
  size: 86
  sha256: 69a8072b1f6b1785b3cb0570214e6c4b1463de0b0689a21aff6c753bbae3daac
```

A fresh public download passed its checksum and strict `1.2.2` ZIP contract.
An independent build from the tagged source with normalized
`SOURCE_DATE_EPOCH=1788909676` compared byte-for-byte with the published GitHub
ZIP.

## Credential and log boundary

All production steps report `success`, including source revalidation immediately
before the only credential-bearing deploy step. A sanitized scan of all 4,784
workflow log lines found:

```text
local repository token literal: absent
WPORG_PASSWORD context lines: 1, masked: 1, unmasked: 0
bare --password arguments: 0
unmasked Authorization headers: 0
```

The WordPress.org username is intentionally a repository variable rather than a
secret and appears in the job environment. The password value was not read by
the verification and was not present unmasked in logs.

## WordPress.org publication

The release workflow created one atomic official SVN commit:

```text
repository: https://plugins.svn.wordpress.org/wp-site-options
revision: 3687381
date: 2026-09-08T23:29:37.000896Z
message: Release wp-site-options 1.2.2
```

A fresh anonymous checkout proved:

- `trunk` is byte-identical to the unpacked GitHub Release ZIP;
- `tags/1.2.2` is byte-identical to the same ZIP;
- `assets` is byte-identical to `.wordpress-org`;
- all six image MIME properties and both copied `.mo` binary MIME properties
  match the exact expected policy;
- the working copy is clean and `tags/1.2.2` last changed in revision `3687381`.

No legacy Windows SVN working copy participated in the release.

## Post-release handoff

Fresh install, update, public-directory propagation, and product smoke evidence
are recorded separately in the independent E6/T27 QA report. Any future
correction must use a new patch version; `v1.2.2` and SVN `tags/1.2.2` are not
rollback targets.
