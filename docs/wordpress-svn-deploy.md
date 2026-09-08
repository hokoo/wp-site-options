# WordPress.org SVN deployment

The deployment script promotes one already-built and strictly validated release
ZIP into the WordPress.org SVN layout. It never builds production files and it
never reuses an existing working copy.

## Prerequisites

- Bash 4 or newer;
- Git;
- Subversion CLI 1.10 or newer with `--password-from-stdin`;
- Python 3.8 or newer;
- Info-ZIP `unzip`;
- GNU-compatible `realpath` and `mktemp`;
- a release ZIP accepted by `scripts/validate-release-zip.sh`.

Canonical directory artwork lives only in `.wordpress-org/`. For an official
deployment every asset must be tracked and the entire directory must be clean in
Git. Assets are restricted to regular, non-empty PNG, JPEG, GIF, or WebP files
with a matching file signature; nested directories, symlinks, special files,
unsafe names, and files larger than 10 MiB are rejected.

## CLI

```text
scripts/deploy-wordpress-svn.sh \
  --zip PATH \
  --version X.Y.Z \
  [--slug wp-site-options] \
  [--svn-url URL] \
  [--dry-run]
```

The default URL is derived exactly as
`https://plugins.svn.wordpress.org/<slug>`. An explicit URL is accepted only
when it is that exact official URL or a simple absolute local `file:///` URL for
the isolated test fixture. Credentials, percent escapes, query strings,
fragments, whitespace, and backslashes are not accepted in URL overrides.

The slug is lowercase ASCII with optional single hyphens. The version must be
normalized `X.Y.Z`, without a `v` prefix or leading zeroes.
Official mode is additionally restricted to the canonical `wp-site-options`
slug. A different slug is permitted only with an isolated local `file:///`
fixture, preventing these hardcoded sources from being sent to another
WordPress.org plugin repository.

## Dry run

Build the deterministic candidate, then inspect the complete SVN delta without
credentials or a commit:

```bash
scripts/build-release-zip.sh dist/wp-site-options.zip
scripts/deploy-wordpress-svn.sh \
  --zip dist/wp-site-options.zip \
  --version 1.2.2 \
  --dry-run
```

The script checks out a fresh working copy into `mktemp`, validates and extracts
the ZIP, compares any existing version tag before changing trunk, synchronizes
the managed paths, schedules SVN changes, validates the final status, and
recompares all three trees byte-for-byte. Dry-run output contains only validated
relative paths and aggregate counts. The script verifies that the working-copy
revision did not change and removes only its exact temporary directory.

Dry-run never reads deployment credentials and never invokes `svn commit`.

## Commit

An official commit requires both environment variables:

```bash
WPORG_USERNAME='wordpress-user' \
WPORG_PASSWORD='application-password' \
scripts/deploy-wordpress-svn.sh \
  --zip dist/wp-site-options.zip \
  --version 1.2.2
```

`WPORG_PASSWORD` is unset from the environment before the commit process starts,
sent to `svn` only over standard input through `--password-from-stdin`, never
placed in argv or output, and not stored because `--no-auth-cache` is always
used. An empty safe delta exits as a no-op before credentials are checked.

The script performs no WordPress.org commit unless all of these conditions hold:

1. the candidate passes the strict release validator for the requested version;
2. official canonical assets are clean and tracked;
3. a fresh checkout succeeds and contains no unsafe managed-path obstruction;
   the official checkout must expose WordPress.org repository UUID
   `b8457f37-d9ea-0310-8a92-e5e31aec5664`, while a local fixture must expose a
   non-empty safe UUID;
4. an existing `tags/<version>` is byte-for-byte identical to the candidate and
   has no transforming properties;
5. trunk and assets match their canonical sources after exact synchronization;
6. the target tag matches the candidate after local `svn copy` or preservation;
7. final XML status contains only safe changes under `trunk`, `assets`, and the
   exact `tags/<version>` path, with no conflict, obstruction, missing,
   unversioned, switched, or outside-path item;
8. a second verbose XML status against repository HEAD reports no remote item or
   property delta under trunk, assets, the target tag, or its tags ancestor;
9. the delta is non-empty and both credentials are present.

The commit targets the verified fresh working copy. A local `file:///` fixture
uses the same checks but intentionally commits without WordPress.org credentials.
It exists for the automated deployment test suite only.

## Existing tags and idempotency

An existing `tags/<version>` is immutable. Its manifest and every file byte are
compared with the candidate before trunk or assets are synchronized. Any
difference is a hard failure; the script never removes, replaces, or edits that
tag. If the tag is absent, it is created only with a local `svn copy` from the
already-synchronized trunk.

When candidate, assets, trunk, and the existing tag already match, final SVN
status is clean. The script exits successfully without credentials or a commit.

## SVN properties and byte preservation

Adds and removals are derived from `svn status --xml`; paths are parsed as XML
and passed to `svn` as separate arguments. Automatic properties are disabled.
The script removes `svn:eol-style`, `svn:keywords`, `svn:externals`, and
`svn:executable` where it manages new trunk/assets content so checkout and
commit cannot translate candidate bytes.

Properties intentionally set by the deployment are:

| Content | `svn:mime-type` |
| --- | --- |
| `.mo` translation files | `application/octet-stream` |
| `.png` WordPress.org assets | `image/png` |
| `.jpg` / `.jpeg` WordPress.org assets | `image/jpeg` |
| `.gif` WordPress.org assets | `image/gif` |
| `.webp` WordPress.org assets | `image/webp` |

The imported WordPress.org asset files currently use
`application/octet-stream`. Therefore the first real dry run is expected to
show property-only changes that normalize those image MIME types. The existing
`.mo` property remains `application/octet-stream`.

After normalization, the complete recursive property manifest is checked.
Trunk and tag allow exactly one
`svn:mime-type=application/octet-stream` property on each `.mo` file and no
property on other nodes. Assets allow exactly their image MIME property on each
file and no directory properties. Unknown or extra properties are a hard
failure.

## Failure behavior

Every validation occurs before a commit. Existing-tag mismatches stop before
trunk synchronization. Invalid status, unsafe paths or properties, tree
mismatches, missing credentials, and SVN errors all produce a non-zero exit.
The final repository-freshness check closes the normal checkout-to-commit race;
SVN's atomic out-of-date protection remains authoritative for a change arriving
after that check. Commit output is forced to the C locale, captured privately,
and its exact `Committed revision N.` record supplies the reported revision.
The script does not update or mix newer remote content into post-commit
evidence.
There is no force-tag replacement, no reusable checkout, no credential cache,
and no cleanup outside the one `mktemp` directory created by the process.
