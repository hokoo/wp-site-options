# E4 independent QA report

- Date: 2026-09-09
- Outcome: **PASS**
- Hosted source commit: `abeb47ee1b12cacfb8c188cb5e6945b0630b2f7a`
- GitHub Actions run: `34252959685` (attempt `1`)
- Artifact ID: `10066750684`
- Artifact name: `wp-site-options-candidate-abeb47ee1b12cacfb8c188cb5e6945b0630b2f7a-34252959685-1`

All T16-T19 acceptance criteria and Definitions of Done passed. Independent QA downloaded the persisted GitHub Actions candidate, verified its checksum and exact inner hash, strictly revalidated it against the exact hosted source, and proved byte identity with a fresh deterministic rebuild. The candidate is accepted as the single release candidate for the tested source commit.

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

Observed result on the initial attempt: `anonymous_download_http=401`, with no redirect. `gh auth status` also exited `1`; `GH_TOKEN` and `GITHUB_TOKEN` were absent. No login was attempted and no credential was requested or read during that attempt. The authenticated independent download that closed this gap is recorded below.

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

The successful hosted step sequence proves GitHub's same-job upload/download transport and fail-closed revalidation. Independent QA additionally downloaded the persisted artifact itself and reproduced its inner bytes from source, satisfying T19 without relying only on CI's own claims.

## Direct-download closure

On 2026-09-09, QA read only the single exact `GITHUB_TOKEN=` value from the ignored local `.env`; the file was not sourced. The value was passed only to the `gh run download` process as `GH_TOKEN` and was never printed or persisted. The exact download target was:

```text
repository=hokoo/wp-site-options
run_id=34252959685
artifact_id=10066750684
artifact_name=wp-site-options-candidate-abeb47ee1b12cacfb8c188cb5e6945b0630b2f7a-34252959685-1
```

The download went to a new directory created with `mktemp`. Verification produced:

```text
download_manifest=exact_two_regular_files
wp-site-options.zip: OK
inner_zip_size=11577 bytes
inner_zip_sha256=43ab994fa0f085d31c22acc5846e4a4c6c095b244a6b9b544800c0e8832b9650
strict_validator=valid version 1.2.2
downloaded_vs_rebuild_cmp=identical
```

The top-level manifest was exactly `wp-site-options.zip` plus `wp-site-options.zip.sha256`; both were regular files and neither was a symlink. `sha256sum -c` passed. A detached worktree at exact commit `abeb47ee1b12cacfb8c188cb5e6945b0630b2f7a` validated the downloaded ZIP with version `1.2.2` and `SOURCE_DATE_EPOCH=1788885888`, rebuilt the ZIP, and matched the downloaded bytes with `cmp`.

Manual inspection was repeated on the downloaded bytes: `unzip -tqq` passed; `unzip -Z1` matched the canonical 14-entry manifest; the only root was `wp-site-options/`; forbidden-file scanning was clean; directories were `0755`, files were `0644`; all timestamps were UTC `2026-09-08 16:44:48`; archive/entry comments and extra fields were absent.

Because the downloaded ZIP was byte-identical to the exact independently rebuilt ZIP already used by the minimum/latest candidate integration above, the prior WordPress 6.0/PHP 7.4.33 and WordPress 7.1/PHP 8.3.33 installation evidence applies to the hosted bytes without rerunning Docker. No implementation defects, missing verification, public-contract regressions, or risk acceptance remain. The expected 90-day GitHub artifact expiration at `2026-12-07T16:45:02Z` is the documented retention policy, not a QA defect.
