# T22 release workflow evidence

## Result

The release automation is implemented with strict tag parsing, repeated quality
gates, deterministic artifact build/service round-trip, draft-first idempotent
GitHub Release publication, and a production-only protected WordPress.org job.
No GitHub tag, release, artifact, or WordPress.org SVN mutation was performed
during this task.

## Implemented contracts

- `scripts/parse-release-tag.sh` accepts only the two approved production tag
  forms and their `beta.N`/`rc.N` prerelease variants. It emits separately
  normalized package/release versions and a boolean prerelease boundary.
- `scripts/test-release-tags.sh` covers valid spellings plus malformed,
  leading-zero, unsupported-channel, build-metadata, path, whitespace, and
  control-character cases.
- `.github/workflows/ci.yml` adds the stable `Release contracts` check and makes
  the release candidate depend on it.
- `.github/workflows/release.yml` has only tag-push triggers, rejects non-created
  or moved tags, requires tag membership in `master`, rechecks package metadata,
  and repeats all quality/contract gates before artifact creation.
- The candidate is built twice at the normalized commit epoch, compared,
  checksummed, uploaded without overwrite, downloaded by returned artifact ID,
  and revalidated.
- `scripts/publish-github-release.sh` permits only exact draft completion or an
  exact published no-op. Its required `--expected-commit` is reverified with
  current public tag/`master` refs before mutations, before draft publication,
  and at successful completion. It has no delete, replace, or clobber path.
- Only the publisher has `contents: write`. The WordPress.org environment job
  is skipped entirely for prereleases, and production credentials occur only on
  its deploy step as `vars.WPORG_USERNAME` and `secrets.WPORG_PASSWORD`.
- Before GitHub publication and again after the production artifact is
  revalidated, the verifier atomically fetches exact lightweight/annotated tag
  and current `master` refs from public GitHub. It requires the original event
  commit for the tag and as an ancestor of current `master`. The latter gate
  runs before the only step that receives WordPress.org credentials.

## Local verification

Executed from a clean committed baseline at `65cfaf6` before the T22 worktree
changes:

```text
$ make test-release-contracts
Release tag parser suite: 35 passed, 0 failed.
WordPress.org SVN deploy fixture suite: 15 passed, 0 failed.
```

The SVN suite used temporary local `file://` repositories only. Its scenarios
include production/idempotent deploys, conflicting tags, unsafe/missing assets,
credential boundaries, property policies, stale working copies, and concurrent
repository changes.

The following static checks also pass:

```bash
bash -n scripts/parse-release-tag.sh scripts/test-release-tags.sh \
  scripts/verify-release-ref.sh scripts/publish-github-release.sh
/tmp/actionlint .github/workflows/ci.yml .github/workflows/release.yml
git diff --check
```

`actionlint` is the locally available v1.7.12 binary. A static expression scan
also confirms that cross-job identifiers and owned output keys use underscore
syntax; the hyphenated `artifact-id` supplied by `actions/upload-artifact` is
accessed with bracket notation.

A static job-order assertion additionally verifies that `Revalidate
WordPress.org candidate` precedes `Verify current remote source before
WordPress.org deployment`, which in turn precedes the credential-bearing
`Deploy verified production candidate to WordPress.org` step. The credentials
occur only in that last step. Static assertions also require both workflow
source checks to pass `--check-master`, and require the publisher's three
freshness calls around its mutation/publication boundaries.

Deterministic artifact parity also passed for package version `1.2.2` and the
normalized `HEAD` epoch `1788904008`: two independent builds compared equal,
both passed the strict validator, and the resulting inner ZIP SHA-256 was
`6f4a30565941615bb081de72296d7bfedc9e0cacb2ea0c4abad55bcebca052a0`.

## Remaining hosted evidence

Hosted run
[`34286435530`](https://github.com/hokoo/wp-site-options/actions/runs/34286435530)
provided the first environment-specific result: `Release contracts` failed
because the `ubuntu-24.04` image did not provide the `svn` executable, so the
candidate correctly remained skipped. The workflow now installs `subversion`
noninteractively, with `--no-install-recommends`, immediately before release
fixtures in both CI and tag-release workflows. The production WordPress.org job
does the same after source/artifact verification and before its credentialed
deploy step. No unrelated job installs Subversion. Local actionlint confirms
the corrected workflow structure. Post-fix hosted CI run
[`34287085705`](https://github.com/hokoo/wp-site-options/actions/runs/34287085705)
then passed all eight jobs, including `Release contracts` and `Release
candidate`.

A real accepted tag push is deliberately not part of local verification because
it would create external state. The first hosted run must confirm:

1. the push event's creation/forced/deleted fields and tag-to-`master` ancestry;
2. completion of all release matrices and contract gates on `ubuntu-24.04`;
3. immutable artifact upload/download by returned artifact ID;
4. the publisher's repository token permission and draft-to-published path;
5. prerelease skipping of the entire `wordpress-org` environment job, or for a
   production tag, its configured variable/secret and protected-environment
   approval;
6. the official WordPress.org SVN commit result for a production release.

Only a successful hosted run may be accepted as release/deployment evidence.
