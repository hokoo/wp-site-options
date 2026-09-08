# T17 release artifact verification

Date: 2026-09-08
Source commit: `a86362c`
Canonical plugin version: `1.2.2`

## Result

Pass. The automated suite proves byte-for-byte reproducibility and rejects all
mandatory unsafe archive classes with the expected validator diagnostic. The
resulting candidate ZIP installs, activates, and passes the lifecycle assertions
on both supported integration profiles.

## Automated artifact suite

Command:

```bash
make test-release
```

Result:

```text
Release artifact suite: 30 passed, 0 failed, 30 total.
SHA256 af64cd2bd04ecd487b005af97564b997fc827985351c894d39b1834dfe3b7274
```

Both archives were built with the explicit even timestamp
`SOURCE_DATE_EPOCH=1700000000`. Separate assertions passed for `cmp` equality
and identical SHA-256 values. The known-good archive also passed the strict
validator.

The suite generated all malicious inputs under a `mktemp` directory in `/tmp`.
It did not extract fixtures itself. Each fixture was required to produce a
non-zero validator exit and the diagnostic assigned to that case; a rejection
for an unrelated reason is a test failure. Coverage includes:

- wrong root, `../`, absolute, backslash, newline/control, and colon/ADS paths;
- duplicate and case-colliding names;
- symlink type, executable file mode, and a directory carrying payload bytes;
- `.env`, `.svn`, and `tests/` development content;
- missing and unexpected allowlisted entries;
- a same-size byte mutation, unsorted entries, and a wrong common timestamp;
- archive comment, entry extra metadata, and entry comment;
- mismatched normalized version `1.2.3` and unnormalized version `v1.2.2`.

The temporary fixture tree is removed by an EXIT trap on pass or failure.

## Candidate validation and install smoke

Repeatable commands:

```bash
SOURCE_DATE_EPOCH=1700000000 make release-zip
SOURCE_DATE_EPOCH=1700000000 scripts/validate-release-zip.sh \
  dist/wp-site-options.zip 1.2.2
PLUGIN_ZIP="$PWD/dist/wp-site-options.zip" scripts/test-integration.sh all
```

Static artifact tests remain separate from the Docker integration command so
`make test-release` is deterministic, quick, and needs no daemon or WordPress
download. The candidate smoke is still fail-closed and uses the existing unique,
project-scoped integration harness.

Observed results:

- strict candidate validation: pass;
- minimum: WordPress `6.0`, PHP `7.4.33`, plugin `1.2.2`, install/activate and
  lifecycle assertions passed;
- latest: WordPress `7.1`, PHP `8.3.33`, plugin `1.2.2`, install/activate and
  lifecycle assertions passed;
- both integration Compose projects removed their containers, networks, and
  volumes; the unrelated `aws-polly_*` containers remained running.

## Static checks

```bash
bash -n scripts/test-release-artifact.sh
python3 -c 'compile(open("tests/release/generate-malicious-zips.py", encoding="utf-8").read(), "tests/release/generate-malicious-zips.py", "exec")'
make -n release-zip test-release
git diff --check
```

All passed. The generator was also compiled successfully with the host Python
`3.8.5`; its generated `__pycache__` was removed after verification.

## Residual scope

The suite does not publish artifacts and does not exercise GitHub artifact
upload/download. Those remain T18 responsibilities. WordPress `latest` is a
moving integration target; the recorded run resolved it to `7.1`.
