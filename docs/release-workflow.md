# Release workflow

The `Release` workflow is the only automated publication path. It runs on tag
pushes, repeats the repository quality gates, builds and round-trips one
immutable release candidate, publishes an idempotent GitHub Release, and sends
production releases to WordPress.org.

It has no manual, release-event, or branch trigger. Its concurrency group is the
constant `wp-site-options-release`, with cancellation disabled, so two release
attempts cannot publish concurrently.

## Tag contract

GitHub tag filters are glob patterns, not regular expressions. The workflow
therefore uses deliberately coarse `v...` and `v-...` filters and treats
`scripts/parse-release-tag.sh` as the authoritative parser.

| Kind | Accepted forms | Package version | GitHub prerelease | WordPress.org |
| --- | --- | --- | --- | --- |
| Production | `vX.Y.Z`, `v-X.Y.Z` | `X.Y.Z` | no | deploy |
| Beta | `vX.Y.Z-beta.N`, `v-X.Y.Z-beta.N` | `X.Y.Z` | yes | skip |
| Release candidate | `vX.Y.Z-rc.N`, `v-X.Y.Z-rc.N` | `X.Y.Z` | yes | skip |

Every numeric component is canonical: `0` is valid, but a multi-digit value
cannot start with zero. Other channels, missing components, build metadata,
extra suffixes, whitespace, control characters, and paths are rejected. Run the
complete accepted/rejected table with:

```bash
make test-release-tags
```

Prerelease ZIPs retain the base `X.Y.Z` plugin package version. The suffix is
release-channel metadata only; it does not rewrite the plugin header, readme, or
archive contents.

The release-intent gate also rejects deleted, updated/forced, and non-creation
push events. The tag must resolve to the event commit, and that commit must be
an ancestor of `master`. The plugin header `Version`, readme `Stable tag`, and
the single version heading under `== Changelog ==` must all equal the parsed
base package version.

## Pipeline and artifact handoff

The tagged commit repeats these gates on `ubuntu-24.04`:

- PHP 7.4 and PHP 8.3 Composer validation, audit, lint, and unit tests;
- WordPress 6.0/PHP 7.4 and latest/PHP 8.3 integration profiles;
- zero-error Plugin Check;
- the authenticated admin Playwright smoke;
- `make test-release-contracts`, covering the tag parser and isolated SVN
  deployment fixtures. This job first installs Debian's `subversion` package
  noninteractively because it is not guaranteed on `ubuntu-24.04`.

The candidate job needs every gate. It derives the UTC ZIP epoch from the tag
commit, rounds it down to ZIP's two-second granularity, builds twice with the
same `SOURCE_DATE_EPOCH`, strictly validates both archives, and requires `cmp`
to prove reproducibility. It uploads only:

- `wp-site-options.zip`;
- `wp-site-options.zip.sha256`.

The artifact name contains commit SHA, run ID, and attempt. Upload uses no
wrapper compression, cannot overwrite an artifact, and has 90-day retention.
The job downloads the artifact by the immutable ID returned by the upload,
checks the inner checksum, compares the service copy with the local candidate,
and strictly validates it again. A pre-upload failure publishes no artifact; a
post-upload failure leaves an artifact in a failed run, which is not a valid
release input.

## GitHub Release publication

Only the `Publish GitHub Release` job has `contents: write`. It receives a fresh
artifact-service download and then checks the checksum, strict ZIP contract,
expected SHA-256, and a deterministic rebuild. Immediately before handing
control to the publisher it atomically fetches the exact tag and current remote
`master` from the public GitHub HTTPS URL into dedicated temporary refs. The tag
must still resolve to the original event commit, and that commit must still be
an ancestor of current `master`.

`scripts/publish-github-release.sh` is fail-closed and draft-first:

- a missing release is created as a draft with `--verify-tag`;
- tag and prerelease state must match exactly;
- only the ZIP and checksum asset names are allowed;
- an existing asset is downloaded and must be byte-identical;
- a missing asset may be added only while the release is a draft;
- assets are never deleted, replaced, or uploaded with clobber semantics;
- both assets are downloaded together and rechecked before the draft is
  published;
- the required `--expected-commit` is checked against freshly fetched tag and
  `master` refs before any Release mutation, again immediately before a draft
  is published, and once more before successful completion;
- rerunning against an identical published release is a successful no-op.

A failure can intentionally leave an unpublished draft, including a partially
uploaded draft. Fix the underlying cause and rerun the same tag workflow; the
script verifies and resumes that draft without replacing existing bytes. An
unexpected or mismatched published release is a hard failure requiring human
investigation, not automated mutation.

## WordPress.org deployment

The whole `Deploy WordPress.org` environment job is skipped for prereleases.
For production tags it starts only after the GitHub Release is successfully
published or identically verified. It downloads the candidate again by
artifact ID, rechecks the checksum/SHA/strict ZIP contract, and calls
`scripts/deploy-wordpress-svn.sh` against the official plugin repository. After
artifact validation and immediately before the credential-bearing deploy step,
it atomically refetches both the exact lightweight/annotated tag and current
remote `master` into dedicated temporary refs. The tag must remain at the
original event commit and that commit must remain an ancestor of `master`. A
deleted/moved tag or rewritten branch therefore fails before WordPress.org
credentials enter any step context. Only after that check, the job installs the
runner's `subversion` package noninteractively and without recommended packages;
the credentials are still scoped solely to the following deploy step.

Configure the protected GitHub environment `wordpress-org` with:

- repository/environment variable `WPORG_USERNAME`;
- environment secret `WPORG_PASSWORD`.

The username and password are exposed only to the final deploy step. The
deploy script passes the password to SVN through standard input, never through
the command line. GitHub environment protection rules may require an approval
before this production-only job starts. A no-op/idempotent SVN state needs no
commit, while a conflicting existing tag remains a hard failure.

## Supply-chain and rerun policy

Workflow permissions default to `contents: read`; every job repeats the narrow
permission, except the GitHub Release publisher's `contents: write`. WordPress
credentials never enter quality, build, artifact, or GitHub publication jobs.
Remote source freshness checks use a constructed public GitHub HTTPS URL,
disable stored credential helpers/prompts, reject stored HTTP authorization
headers, and clean up only their dedicated local refs.
All third-party Actions are pinned to reviewed 40-character commits documented
in [CI](ci.md); runners are explicitly `ubuntu-24.04`.

Only a successful tag workflow is release evidence. Do not consume artifacts
from failed or cancelled runs. Rerun the same immutable tag rather than moving
or recreating it. Tag deletion, retargeting, or force-update is outside the
release contract and is rejected.

Creating a real tag is intentionally the remaining hosted verification step.
Local checks cannot prove GitHub event fields, artifact-service IDs, token
permissions, environment approvals, GitHub Release mutation, or the official
WordPress.org commit path without causing the corresponding external effects.
