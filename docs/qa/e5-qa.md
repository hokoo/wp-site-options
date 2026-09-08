# E5 independent QA

Date: 2026-09-09
QA source commit: `97c63b21ecb1fe76b415d98670094bfc1342972e` (`master`)
Outcome: **PASS**

## Scope and safety boundary

This review independently checked the acceptance criteria and Definition of
Done for T20-T23 and the epic-level T24 criteria. No production tag, GitHub
Release, WordPress.org commit, or credential value was created, read, or
printed. The official WordPress.org repository was accessed only through an
anonymous fresh checkout and `--dry-run` metadata/status operations.

The worktree was clean at the start of QA. The only repository change produced
by QA is this report.

## Automated release contracts

The following commands passed:

```bash
env -u WPORG_USERNAME -u WPORG_PASSWORD make test-release-contracts
/tmp/actionlint.uJtT8L/actionlint \
  .github/workflows/ci.yml .github/workflows/release.yml
bash -n scripts/deploy-wordpress-svn.sh \
  scripts/parse-release-tag.sh scripts/test-release-tags.sh \
  scripts/test-svn-deploy.sh scripts/verify-release-ref.sh \
  scripts/publish-github-release.sh
git diff --check
```

Results:

```text
Release tag parser suite: 35 passed, 0 failed.
WordPress.org SVN deploy fixture suite: 15 passed, 0 failed.
```

The 15 disposable `file://` SVN scenarios independently passed initial dry
run, one-revision atomic deployment, exact tree/byte/property comparison,
credential-free identical rerun, stale add/delete reconciliation,
property-only normalization, differing/unsafe immutable-tag rejection,
managed symlink rejection, externals rejection, and the freshness-race
negative. Expected failures returned non-zero and did not create a deploy
revision.

## Tag and metadata contract

The parser table covers four production examples, four prerelease examples,
22 malformed tags, a GitHub output case, and four invalid CLI boundary cases.
Independent spot checks produced:

```text
v1.2.2          -> package_version=1.2.2, release_version=1.2.2, is_prerelease=false
v-1.2.2         -> package_version=1.2.2, release_version=1.2.2, is_prerelease=false
v1.2.2-beta.1   -> package_version=1.2.2, release_version=1.2.2-beta.1, is_prerelease=true
v-1.2.2-rc.1    -> package_version=1.2.2, release_version=1.2.2-rc.1, is_prerelease=true
```

The source metadata gate also matches the normalized package version:

```text
plugin header Version: 1.2.2
readme Stable tag:     1.2.2
changelog contract:    one Changelog section and one 1.2.2 heading (1:1)
```

## Workflow and credential boundaries

`actionlint` passed both workflows. A separate static inventory found 14
Action uses in CI and 19 in the release workflow; all 33 are pinned to full
40-character commit SHAs.

- Workflow defaults are `contents: read`. CI has no write-permission job, and
  `publish_github` is the only release job with `contents: write`.
- `deploy_wordpress_org` requires the intent, immutable candidate, and GitHub
  publication jobs. Its job-level condition requires
  `is_prerelease == 'false'`; the job also reparses the tag and requires
  `is_prerelease=false`. A prerelease therefore cannot reach a WordPress.org
  step or receive its credentials.
- `${{ vars.WPORG_USERNAME }}` and `${{ secrets.WPORG_PASSWORD }}` each occur
  exactly once in workflow source, only in the final production deploy step.
  Artifact and current-source validation steps contain neither context.
- The deploy script exits from `--dry-run` and from a clean idempotent no-op
  before reading credentials. A non-empty official commit validates both
  values, unsets their environment names, supplies the password only through
  `--password-from-stdin`, disables auth caching, and captures commit output
  privately.
- Candidate upload disables overwrite, the returned artifact ID is propagated
  across jobs, and every consumer checks the checksum, expected inner SHA, two
  exact files, and the strict ZIP contract. GitHub publication additionally
  performs a deterministic local rebuild and byte comparison.
- Release publication is draft-first and does not contain a clobber/delete
  path. Existing assets must compare byte-for-byte, and an already published
  release must contain the exact asset set.
- Current public tag and `master` are atomically refetched and checked against
  the event commit before publication and before production deployment. The
  publisher repeats that check before its first mutation, immediately before
  making a draft public, and before successful completion.
- SVN status and properties are parsed as XML, paths are constrained to the
  three managed roots, existing tags are compared before trunk synchronization,
  and the remote freshness check precedes the single atomic SVN commit.

The sanitized T23 configuration evidence was reviewed: it records the
repository variable/secret names as present without values, read-only default
workflow permissions, the `wordpress-org` environment, and its two production
tag policies. This QA accessed no credential values.

## Independent official WordPress.org dry run

The T23 candidate was independently reconstructed from source commit
`c319293833119ff7dd3b15823ff6dece5aeaaa61`. Its commit epoch `1788907221` was
normalized to the two-second ZIP epoch `1788907220`:

```bash
SOURCE_DATE_EPOCH=1788907221 scripts/build-release-zip.sh /tmp/.../wp-site-options.zip
env -u WPORG_USERNAME -u WPORG_PASSWORD SOURCE_DATE_EPOCH=1788907221 \
  scripts/deploy-wordpress-svn.sh \
  --zip /tmp/.../wp-site-options.zip --version 1.2.2 --dry-run
```

The independently produced inner ZIP SHA-256 exactly matched T23:

```text
5479aef0dbba0b32b9f4935129bcaa00dbb5b80c77aa5e2cdb042b9e1e055640
```

The fresh official dry run passed with no credentials and reproduced the
documented delta exactly:

```text
added=1 modified=16 deleted=0 replaced=0 property_modified=6 total=23
Dry-run complete: repository revision remained 3687366; no commit attempted.
```

The changes consist only of the new `tags/1.2.2` copy and its eight candidate
files, the same eight candidate files in `trunk`, and MIME-property
normalization for the six canonical image assets. There were no deletions,
replacements, or unexplained paths.

A separate anonymous metadata query after the dry run confirmed the official
repository UUID `b8457f37-d9ea-0310-8a92-e5e31aec5664` and plugin subtree
last-changed revision `3283155`, matching the T23 baseline. The global
WordPress.org repository revision advanced independently while QA ran, but the
plugin subtree did not change.

## Hosted evidence

The public GitHub Actions API independently confirms that
[run 34287085705](https://github.com/hokoo/wp-site-options/actions/runs/34287085705)
completed successfully on
`c319293833119ff7dd3b15823ff6dece5aeaaa61`, attempt 1. All eight jobs report
`success`, including both PHP versions, both WordPress integration profiles,
Plugin Check, authenticated admin smoke, Release contracts, and Release
candidate.

## Defects, missing verification, and residual risk

No E5 acceptance or Definition-of-Done defect was found. No risk acceptance is
needed to close E5.

A real tag-push workflow, GitHub Release mutation, environment credential
resolution during that tag run, and the final WordPress.org commit remain
intentionally unexecuted. They are production cutover evidence for T26, not
T24, and require explicit production approval.
