# E4 independent QA report

- Date: 2026-09-08
- Outcome: **BLOCKED_PENDING_DIRECT_DOWNLOAD**
- Hosted source commit: `abeb47ee1b12cacfb8c188cb5e6945b0630b2f7a`
- GitHub Actions run: `34252959685` (attempt `1`)
- Artifact ID: `10066750684`
- Artifact name: `wp-site-options-candidate-abeb47ee1b12cacfb8c188cb5e6945b0630b2f7a-34252959685-1`

All independently available T16-T18 checks passed. The sole unmet T19 acceptance criterion is an independent QA download and revalidation of the bytes stored by GitHub Actions. The anonymous download endpoint returned HTTP `401`, and this environment has no authenticated GitHub CLI session or token. The candidate must not be promoted as the single release candidate until that check is resumed with read-only Actions access.

## Hosted run and artifact evidence

Anonymous, read-only GitHub API requests confirmed that run `34252959685` was a `push` to `master` at the exact source commit above. It completed with `success` on 2026-09-08. The jobs endpoint returned seven jobs and every job completed successfully:

- `PHP quality / PHP 7.4`;
- `PHP quality / PHP 8.3`;
- `WordPress integration / minimum`;
- `WordPress integration / latest`;
- `Plugin Check`;
- `Authenticated admin smoke`;
- `Release candidate` (job ID `102152029389`).

The release-candidate job API showed successful steps in the required order: metadata derivation, two builds and validations, upload, fresh-download-path guard, download by immutable artifact ID, downloaded-candidate verification, and summary publication.

The run exposes exactly one non-expired artifact:

```text
id=10066750684
name=wp-site-options-candidate-abeb47ee1b12cacfb8c188cb5e6945b0630b2f7a-34252959685-1
size_in_bytes=11959
service_wrapper_digest=sha256:c95fcf446b14cf915bebc4b12360f0cc266575a0da77904a6dfd0df45cc142b5
created_at=2026-09-08T16:46:31Z
expires_at=2026-12-07T16:45:02Z
expired=false
```

The service digest and size describe GitHub's artifact wrapper, not the release ZIP inside it. The independently rebuilt inner `wp-site-options.zip` is 11,577 bytes and has SHA-256:

```text
43ab994fa0f085d31c22acc5846e4a4c6c095b244a6b9b544800c0e8832b9650
```

These two digests are intentionally different and are not interchangeable.

The anonymous direct-download probe was:

```bash
curl -sS -o /dev/null \
  -w 'anonymous_download_http=%{http_code}\nredirect=%{redirect_url}\n' \
  -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2022-11-28' \
  https://api.github.com/repos/hokoo/wp-site-options/actions/artifacts/10066750684/zip
```

Observed result: `anonymous_download_http=401`, with no redirect. `gh auth status` also exited `1`; `GH_TOKEN` and `GITHUB_TOKEN` were absent. No login was attempted and no credential was requested or read.

## Independent deterministic build and ZIP validation

Tests ran from a detached temporary checkout of exact commit `abeb47ee1b12cacfb8c188cb5e6945b0630b2f7a`, not from the later documentation/backlog commit. The default source epoch was `1788885888`, already aligned to ZIP's two-second granularity.

Two independent default-epoch builds completed successfully. `cmp` returned `0`, and both `sha256sum` results were exactly:

```text
43ab994fa0f085d31c22acc5846e4a4c6c095b244a6b9b544800c0e8832b9650
```

`scripts/validate-release-zip.sh <zip> 1.2.2` and `unzip -tqq` both exited `0`. Manual `unzip -Z1` inspection found exactly 14 sorted entries under the single `wp-site-options/` root. A canonical manifest comparison against `plugin-dir/` matched exactly. No `.env`, `.svn`, development/test/docs/dist files, dependency directories, local artifacts, symlinks, traversal paths, or unexpected entries were present.

Manual `zipinfo -l` inspection showed directories at mode `0755`, files at mode `0644`, and all entries at the normalized UTC time `2026-09-08 16:44`. File bytes and metadata were also independently covered by the strict validator.

The complete release artifact suite was rerun:

```bash
make test-release
```

Result: `30 passed, 0 failed, 30 total`. This included controlled non-zero rejection cases for an outside root, traversal, absolute/backslash/control/ADS paths, duplicates and case collisions, symlinks, executable modes, directory payload, `.env`, `.svn`, test content, missing/unexpected entries, byte mutation, unsorted entries, timestamp/comment/extra metadata, and version mismatch. Its fixed-fixture epoch reproducibility hash was `af64cd2bd04ecd487b005af97564b997fc827985351c894d39b1834dfe3b7274`; that test-fixture hash is not the hosted commit-epoch candidate hash above.

## Candidate ZIP installation smoke

The independently rebuilt commit-epoch ZIP was supplied through the artifact input rather than installed from the working tree:

```bash
PLUGIN_ZIP=/tmp/wpso-e4qa-abeb47e/output/wp-site-options-a.zip \
WP_SITE_OPTIONS_IT_ARTIFACTS=/tmp/wpso-e4qa-abeb47e/artifacts \
./scripts/test-integration.sh all
```

Both clean, uniquely named profiles passed installation, activation, lifecycle, persistence, field registration, and sanitization assertions:

| Profile | WordPress | PHP | Plugin | Result | `wp-debug.log` |
| --- | ---: | ---: | ---: | --- | ---: |
| minimum | 6.0 | 7.4.33 | 1.2.2 | passed | 0 bytes |
| latest | 7.1 | 8.3.33 | 1.2.2 | passed | 0 bytes |

The projects `wpositminimum66785` and `wpositlatest67947` removed their containers, networks, and volumes on completion. The unrelated running `aws-polly` containers retained IDs `11beee3aa768`, `a75aef9d5a0b`, and `d31a4402a6e6` and remained running. Temporary QA checkout/output was cleaned after evidence collection.

## Workflow review

Independent static inspection and `actionlint` (exit `0`) confirmed:

- `Release candidate` uses the same draft-PR exclusion and needs all four upstream job IDs, covering all six pre-existing gates;
- global and job permissions are `contents: read`, with no write permission, release credential, `secrets.*`, WPORG, or deployment reference;
- metadata validation, double build, strict validation, `cmp`, and inner checksum verification precede upload;
- upload is not guarded by `always()`, uses a commit/run/attempt-qualified name, `if-no-files-found: error`, 90-day retention, `overwrite: false`, and wrapper compression level `0`;
- the same job requires a fresh path, downloads by the returned immutable artifact ID, requires exactly the ZIP/checksum pair, verifies `sha256sum -c`, compares with pre-upload bytes, and runs the strict validator again;
- all 13 external Action uses are pinned to full 40-character commit SHAs;
- summary fields are format-validated before publication.

The successful hosted step sequence is strong transport evidence: GitHub's same job uploaded, downloaded, compared, checksum-checked, and strictly revalidated the candidate. The deterministic local rebuild independently reproduces the recorded inner ZIP hash. Neither substitutes for T19's explicit requirement that the independent QA actor directly download and revalidate the persisted artifact.

## Blocker and exact resume path

No implementation defect was found. No risk acceptance is recommended: one narrowly scoped authority is needed — a GitHub fine-grained token or authenticated session for repository `hokoo/wp-site-options` with **Actions: read** only. Repository contents write, Actions write, GitHub Release write, WordPress.org, and SVN credentials are not needed.

After exposing that token as `GH_TOKEN`, resume with the exact hosted IDs:

```bash
qa_dir="$(mktemp -d /tmp/wpso-e4qa-resume.XXXXXX)"
artifact_name='wp-site-options-candidate-abeb47ee1b12cacfb8c188cb5e6945b0630b2f7a-34252959685-1'

gh run download 34252959685 \
  --repo hokoo/wp-site-options \
  --name "${artifact_name}" \
  --dir "${qa_dir}/download"

diff -u \
  <(printf '%s\n' wp-site-options.zip wp-site-options.zip.sha256) \
  <(find "${qa_dir}/download" -mindepth 1 -maxdepth 1 -type f -printf '%f\n' | sort)
( cd "${qa_dir}/download" && sha256sum -c wp-site-options.zip.sha256 )
test "$(sha256sum "${qa_dir}/download/wp-site-options.zip" | awk '{print $1}')" = \
  '43ab994fa0f085d31c22acc5846e4a4c6c095b244a6b9b544800c0e8832b9650'

git worktree add --detach "${qa_dir}/source" abeb47ee1b12cacfb8c188cb5e6945b0630b2f7a
SOURCE_DATE_EPOCH=1788885888 \
  "${qa_dir}/source/scripts/validate-release-zip.sh" \
  "${qa_dir}/download/wp-site-options.zip" 1.2.2
SOURCE_DATE_EPOCH=1788885888 \
  "${qa_dir}/source/scripts/build-release-zip.sh" "${qa_dir}/local.zip"
cmp "${qa_dir}/local.zip" "${qa_dir}/download/wp-site-options.zip"
PLUGIN_ZIP="${qa_dir}/download/wp-site-options.zip" \
WP_SITE_OPTIONS_IT_ARTIFACTS="${qa_dir}/integration-evidence" \
  "${qa_dir}/source/scripts/test-integration.sh" all
```

The download must contain exactly `wp-site-options.zip` and `wp-site-options.zip.sha256`; checksum, strict validation, deterministic `cmp`, and both installation profiles must pass. Only then can T19 become `PASS` and the artifact be accepted as the single release candidate. The artifact is currently scheduled to expire at `2026-12-07T16:45:02Z`.
