# Release and recovery runbook

This is the maintainer runbook for GitHub and WordPress.org releases of
WP Site Options. Git `master` is the canonical source. Installable code comes
only from `plugin-dir/`; WordPress.org listing assets come only from
`.wordpress-org/`.

The legacy Windows SVN working copy is read-only historical/reference material
after cutover. Do not edit it, copy release files from it, or use it to commit a
new version.

## Production authority and protections

A Git tag is production intent. The only accepted stable forms are:

```text
vX.Y.Z
v-X.Y.Z
```

Both normalize to package version `X.Y.Z`. The accepted prerelease forms are
`vX.Y.Z-beta.N`, `v-X.Y.Z-beta.N`, `vX.Y.Z-rc.N`, and `v-X.Y.Z-rc.N`.
Prereleases publish a GitHub prerelease but skip the entire WordPress.org job.

Repository protection must enforce this contract:

- `master` changes arrive through a pull request;
- the pull request branch is current with `master` and all eight checks pass;
- protection includes administrators, requires linear history and resolved
  conversations, and rejects force-pushes and branch deletion;
- matching `v*` release tags can be created, but cannot be updated or deleted;
- the `wordpress-org` environment has only the two custom tag policies
  `v[0-9]*.[0-9]*.[0-9]*` and `v-[0-9]*.[0-9]*.[0-9]*`; the workflow's strict
  parser and production-only condition remain authoritative because GitHub
  patterns are deliberately coarse.

The exact required GitHub Actions checks are:

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

The repository uses a zero-approval pull-request minimum so a single maintainer
is not locked out, but the PR, up-to-date branch, complete CI, linear-history,
and conversation-resolution boundaries still apply. A future multi-maintainer
project should raise the approval count and require review of the latest push.

The environment currently has no reviewer or timer gate. Creating the tag is
therefore the human approval boundary: never push a production tag until the
release owner explicitly approves the irreversible WordPress.org publication.

## One-time and periodic configuration check

Do not print credential values. Confirm only that the repository variable and
secret names exist:

```bash
gh api repos/hokoo/wp-site-options/actions/variables \
  --jq 'any(.variables[]; .name == "WPORG_USERNAME" and (.value | length) > 0)'
gh secret list --repo hokoo/wp-site-options \
  --json name --jq 'any(.[]; .name == "WPORG_PASSWORD")'
```

Both commands must output `true`. The workflow references
`vars.WPORG_USERNAME` and `secrets.WPORG_PASSWORD` only in its final production
deploy step. The GitHub environment is `wordpress-org`; workflow permissions
are read-only except for the dedicated GitHub Release publisher.

Recheck branch/tag/environment protection in the GitHub repository settings
after changing workflow job names, tag formats, repository ownership, default
branch, or maintainer access. Never weaken a protection merely to make a failed
release pass.

## Prepare a release change

1. Choose a new SemVer package version. A WordPress.org tag is immutable, so a
   published or conflicting version number can never be reused for different
   bytes.
2. Update the `Version` header in `plugin-dir/wp-site-options.php`, the
   `Stable tag` in `plugin-dir/readme.txt`, and add exactly one matching entry
   under `== Changelog ==`.
3. Open a pull request targeting `master`. Do not include `.env`, archives,
   logs, database data, `local-dev/`, dependencies, or SVN metadata.
4. Wait for all eight required checks and merge without a merge commit.
5. Pull/fetch the resulting `master`, verify the exact commit, and obtain the
   release owner's explicit production approval.

Useful local preflight before opening the pull request:

```bash
composer validate --strict --no-interaction
composer audit --no-interaction
composer lint:php
composer test:unit
scripts/test-integration.sh minimum
scripts/test-integration.sh latest
scripts/plugin-check.sh
make test-release-contracts
make test-release
npm audit --audit-level=high
npm run test:e2e
```

The integration, Plugin Check, and browser commands use Docker and may create
ignored diagnostics. They do not publish anything. `make test-release` proves
the deterministic and negative ZIP contracts; the CI `Release candidate` job
provides the authoritative artifact-service round trip.

## Final preflight on `master`

Start from a clean, current checkout and choose exactly one approved tag form:

```bash
git switch master
git fetch --prune origin master
git merge --ff-only origin/master
test -z "$(git status --porcelain=v1 --untracked-files=no)"

release_tag=v1.2.2
release_commit="$(git rev-parse HEAD)"
scripts/parse-release-tag.sh "${release_tag}"
git merge-base --is-ancestor "${release_commit}" origin/master
```

Confirm that the parser's `package_version` equals the plugin header, stable
tag, and changelog version. Confirm the CI run for `release_commit` completed
successfully, the WordPress.org version does not already contain different
bytes, and the latest real dry-run has no unexplained path or deletion.

For `1.2.2`, the accepted dry-run evidence and candidate checksum are recorded
in [T23 Actions/SVN evidence](qa/t23-actions-svn-dry-run.md), and E5 has an
independent [PASS report](qa/e5-qa.md). Rebuild after a source commit changes;
never reuse an earlier checksum as evidence for a different commit.

## Create the release

This section performs external production mutations. Stop unless the release
owner has explicitly approved this exact version and commit.

Create one annotated immutable tag and push only that ref:

```bash
release_tag=v1.2.2
release_commit="$(git rev-parse HEAD)"
git tag -a "${release_tag}" "${release_commit}" \
  -m "WP Site Options 1.2.2"
git push origin "refs/tags/${release_tag}"
```

Do not use `--force`, delete the tag, or recreate it. The `Release` workflow:

1. verifies the creation event, tag grammar, commit membership in current
   `master`, and package metadata;
2. repeats every quality gate;
3. builds the candidate twice and round-trips the immutable artifact by ID;
4. publishes an exact, draft-first GitHub Release with the ZIP and checksum;
5. for production only, revalidates the artifact/source and atomically commits
   `trunk`, `.wordpress-org` assets, and `tags/X.Y.Z` to WordPress.org SVN.

Monitor the run without exposing credentials:

```bash
gh run list --repo hokoo/wp-site-options --workflow Release --limit 10
gh run watch RUN_ID --repo hokoo/wp-site-options --exit-status
gh run view RUN_ID --repo hokoo/wp-site-options
```

Record the immutable Git commit, tag, run URL, artifact ID, ZIP SHA-256, GitHub
Release URL, and resulting WordPress.org SVN revision in the post-release QA
report.

## Post-release verification

Download both public release assets into a new temporary directory and verify
the checksum before opening the ZIP:

```bash
release_dir="$(mktemp -d)"
gh release download "${release_tag}" --repo hokoo/wp-site-options \
  --pattern 'wp-site-options.zip' \
  --pattern 'wp-site-options.zip.sha256' \
  --dir "${release_dir}"
(
  cd "${release_dir}"
  sha256sum -c wp-site-options.zip.sha256
)
```

Then verify from fresh sources, never the legacy working copy:

- GitHub Release tag, prerelease flag, ZIP, checksum, and workflow conclusion;
- WordPress.org `trunk`, `assets`, and `tags/X.Y.Z` trees and properties;
- fresh install and activation from the public ZIP;
- update path, Settings → Reading save/reload, and representative public API;
- WordPress.org page/stable-version propagation and absence of PHP errors.

## Recovery and rerun matrix

| Observed state | Safe response |
| --- | --- |
| Workflow failed before any GitHub draft | Fix transient configuration/runner issues and rerun the same immutable tag. If source bytes must change, prepare a new patch version and tag. |
| Incomplete matching GitHub draft exists | Rerun the same tag. The publisher verifies existing bytes, adds only missing approved assets, and publishes only an exact draft. |
| Matching GitHub Release is already published; SVN did not commit | Correct the external SVN/configuration issue and rerun the same workflow. GitHub publication becomes a verified no-op; SVN receives the same candidate. |
| WordPress.org already contains identical tag/trunk/assets | Rerun is a credential-free or commit-free no-op as applicable; record the existing revision after verification. |
| Existing GitHub asset, Release state, or SVN tag differs | Stop. Do not clobber, delete, move, or replace it. Preserve logs and prepare a new patch version after investigation. |
| SVN commit succeeded but the runner result is uncertain | Inspect a fresh anonymous SVN checkout first, then rerun the same immutable tag; the deploy path verifies exact bytes and avoids a duplicate commit. |
| A defect is found after WordPress.org publication | WordPress.org tags are not rolled back or overwritten. Ship a tested new patch version; communicate impact separately if needed. |
| A credential may have leaked | Cancel the run, rotate/revoke it in GitHub and WordPress.org, inspect logs/artifacts, and do not resume until the exposure is contained. |

Never delete or retarget a published Git tag as a rollback. Never overwrite an
SVN tag. A Git revert can repair `master`, but it cannot undo a GitHub Release or
WordPress.org publication; production correction always uses a new version.

## First automated release

The first automated stable release, `v1.2.2`, was explicitly approved and
published on 2026-09-09. Its immutable source/artifact/SVN evidence is recorded
in [T26 production release evidence](qa/t26-release-1.2.2.md). Future releases
must repeat this runbook with a new version and explicit production approval;
approval of `1.2.2` does not authorize another release.
