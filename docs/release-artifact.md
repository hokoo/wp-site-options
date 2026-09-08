# Deterministic release artifact

The release artifact is always built from the canonical `plugin-dir/` and written to `dist/wp-site-options.zip` by default. Its only top-level entry is `wp-site-options/`; Composer, test, documentation, local-development, and repository tooling are not copied into the plugin package.

## Prerequisites

- Bash 4 or newer;
- Git;
- Info-ZIP `zip` and `unzip`;
- Python 3 with the standard-library `zipfile` module;
- GNU-compatible `find`, `sort`, `touch`, `chmod`, `cmp`, `awk`, `sed`, `realpath`, and `mktemp`.

No Composer or Node dependency is required to build or validate the archive.

The release file allowlist covers PHP, text, CSS, JavaScript, JSON, XML, WordPress translation files, common web images/fonts, and extensionless `LICENSE`, `COPYING`, or `NOTICE` files. A new production file type must be reviewed and added deliberately; it is never included implicitly.

## Build

From the repository root:

```bash
scripts/build-release-zip.sh
```

An optional output path may be supplied:

```bash
scripts/build-release-zip.sh /tmp/wp-site-options.zip
```

The builder:

1. requires `plugin-dir/` to be clean, fully tracked by Git, free of symlinks/special files, and composed of releasable file types;
2. derives the default timestamp from the checked-out Git `HEAD` commit, which also works with a fetch-depth-1 release checkout;
3. copies only `plugin-dir/` into a temporary `wp-site-options/` staging directory;
4. normalizes directories to `0755`, files to `0644`, and every timestamp to the selected UTC epoch rounded down to ZIP's two-second granularity;
5. archives all entries in byte-sorted order with Info-ZIP `-X`, removing variable extra metadata;
6. runs the strict validator before atomically replacing the requested artifact path.

For reproducible rebuilds from an externally recorded epoch, set an integer `SOURCE_DATE_EPOCH` in the ZIP-supported 1980–2107 range:

```bash
SOURCE_DATE_EPOCH=1700000000 scripts/build-release-zip.sh
```

Validation derives the same expected timestamp from `HEAD`. When validating an artifact built with an override, supply that same override:

```bash
SOURCE_DATE_EPOCH=1700000000 scripts/validate-release-zip.sh dist/wp-site-options.zip 1.2.2
```

The output path and all its existing parent components must not be symlinks. An output beneath `plugin-dir/` is rejected.

## Validate

The validator takes the archive path and an already normalized `X.Y.Z` version:

```bash
scripts/validate-release-zip.sh dist/wp-site-options.zip 1.2.2
```

Prefixes such as `v`, prerelease suffixes, build metadata, and zero-padded numeric components are not accepted at this layer. Tag normalization belongs to the release-intent layer; the artifact validator compares the normalized version exactly.

Before decompression or extraction, validation inspects every central-directory record and bounds declared archive/entry sizes against the canonical source. It rejects:

- absolute paths, `.`/`..` components, backslashes, colons/NTFS ADS ambiguity, empty components, control characters, embedded newlines, and non-NFC Unicode names;
- missing, duplicate, Unicode-normalized case-colliding, multiple, or incorrectly named archive roots;
- symlinks, special files, encrypted entries, unsafe/non-normalized modes, non-empty directory entries, entry/archive comments, extra ZIP metadata, and unsupported compression methods;
- hidden paths, development directories/files, secret-like names, archives, database/log/key/executable payloads, and other non-allowlisted file types;
- unsorted entries, timestamps that differ from the expected two-second UTC epoch, unexpected files, missing production files, and sizes that differ from canonical `plugin-dir/`.

Only after these zip-slip, size, and metadata checks pass does the validator run `unzip -t`. A successful integrity test is followed by extraction into `mktemp`, exact directory/file manifest and byte comparison with `plugin-dir/`, and all three release-version checks:

- `Version` in `wp-site-options.php`;
- `Stable tag` in `readme.txt`;
- exactly one `== Changelog ==` heading and one `= X.Y.Z =` section beneath it in `readme.txt`.

Both scripts clean temporary staging/extraction directories on success or failure. The release ZIP contains no runtime `vendor/` directory or development dependency tree.

## Reproducibility check

Run the automated reproducibility and negative-fixture suite:

```bash
make test-release
```

The suite builds twice with an explicit fixed `SOURCE_DATE_EPOCH`, compares both
archives byte-for-byte and by SHA-256, validates the good archive, then proves
that malicious path, metadata, manifest, byte-content, and version fixtures are
rejected with their expected diagnostics. Fixtures exist only in a scoped
temporary directory and are removed when the suite exits.

For a manual comparison:

```bash
scripts/build-release-zip.sh /tmp/wp-site-options-a.zip
scripts/build-release-zip.sh /tmp/wp-site-options-b.zip
cmp /tmp/wp-site-options-a.zip /tmp/wp-site-options-b.zip
sha256sum /tmp/wp-site-options-a.zip /tmp/wp-site-options-b.zip
```

For the verified canonical source and explicit epoch `1700000000`, two clean builds both produced:

```text
af64cd2bd04ecd487b005af97564b997fc827985351c894d39b1834dfe3b7274  wp-site-options.zip
```
