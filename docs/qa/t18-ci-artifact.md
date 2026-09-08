# T18 CI release-candidate evidence

Date: 2026-09-08
Source commit: `abeb47ee1b12cacfb8c188cb5e6945b0630b2f7a`
Canonical plugin version: `1.2.2`

## Result

Pass. Local/static verification and the hosted artifact-service path both
succeeded. The final `Release candidate` job ran after all four upstream job
IDs, so its upload occurred only after all six existing quality gates passed.

## Workflow contract

The final job:

- runs on `ubuntu-24.04` with only `contents: read` and the established
  draft-pull-request exclusion;
- validates the normalized `X.Y.Z` plugin-header version and derives the
  checked-out `HEAD` epoch, rounded down to ZIP's two-second granularity;
- builds and strictly validates two candidates with that exact
  `SOURCE_DATE_EPOCH`, then requires byte identity with `cmp`;
- uploads only `wp-site-options.zip` and its inner SHA-256 file, after every
  pre-upload check has passed;
- uses the immutable name
  `wp-site-options-candidate-<commit-sha>-<run-id>-<run-attempt>`, 90-day
  retention, no overwrite, and zero artifact-wrapper compression;
- downloads the upload by the artifact ID returned by the service into a fresh
  path, verifies the inner checksum and byte identity, and applies the strict
  ZIP validator again with the same version and epoch;
- emits only format-validated commit, version, epoch, ZIP hash, and upload
  artifact outputs to the job summary.

A post-upload failure leaves an immutable diagnostic artifact attached to a
failed run. Release consumers must therefore accept candidates from successful
workflow runs only.

## Action and workflow validation

The official `actionlint` v1.7.12 Linux archive was checked against its
published checksum before use:

```text
8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8  actionlint_1.7.12_linux_amd64.tar.gz
```

Command and result:

```bash
/tmp/actionlint .github/workflows/ci.yml
```

No diagnostics; exit status `0`.

`actions/download-artifact` tag provenance was checked against the official
repository:

```bash
git ls-remote https://github.com/actions/download-artifact.git \
  refs/tags/v8.0.1 refs/tags/v8.0.1^{}
```

```text
3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c  refs/tags/v8.0.1
```

The workflow pins that exact 40-character commit. All other action references
remain pinned to their existing full commit SHAs. Static inspection found no
secret or release-credential references and no write permission.

## Local artifact parity

The workflow's build, validation, reproducibility, checksum, and fresh-copy
verification path was reproduced locally. The temporary second build and
download directory were created under `mktemp` and removed by an EXIT trap.

Observed metadata for the pre-commit local parity run:

```text
version=1.2.2
epoch=1788885106
zip_sha256=7fc8efbd9e3f20b72bedbdf428f6256110ad5bc5a9464e0475c20b2e563b23b4
```

Both strict validator runs passed, `cmp` proved both builds byte-identical,
`sha256sum -c` passed for the candidate and fresh copy, the fresh ZIP matched
the local candidate, and the strict validator passed again on that copy.

An additional local build from the committed hosted source used epoch
`1788885888` and produced inner ZIP SHA-256
`43ab994fa0f085d31c22acc5846e4a4c6c095b244a6b9b544800c0e8832b9650`.

## Hosted proof

[GitHub Actions run 34252959685](https://github.com/hokoo/wp-site-options/actions/runs/34252959685)
was a `push` to `master` at the source commit above. It completed with
`success`; all seven named jobs passed, including `Release candidate`.

The public jobs API reports successful completion of each release-candidate
step in order: metadata derivation, double build/validation, upload, fresh-path
guard, download by artifact ID, downloaded-candidate verification, and summary.
The run exposes exactly one non-expired artifact:

```text
id=10066750684
name=wp-site-options-candidate-abeb47ee1b12cacfb8c188cb5e6945b0630b2f7a-34252959685-1
size=11959 bytes
service_digest=sha256:c95fcf446b14cf915bebc4b12360f0cc266575a0da77904a6dfd0df45cc142b5
expires=2026-12-07T16:45:02Z
```

The artifact-service digest identifies GitHub's wrapper and is intentionally
distinct from the inner release-ZIP checksum. Direct external download remains
part of independent E4 QA; T18 itself proves GitHub's same-job upload/download
transport and fail-closed revalidation path.
