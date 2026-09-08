# T21 isolated SVN deployment fixtures

Date: 2026-09-09
Source commit: `632d558`
Plugin version: `1.2.2`

## Result

Pass. The complete fixture suite used only disposable `svnadmin` repositories
below one validated `mktemp` directory and local `file:///` URLs. It made no
WordPress.org request and ran every deploy with `WPORG_USERNAME` and
`WPORG_PASSWORD` explicitly unset.

## Automated suite

Command:

```bash
make test-svn
```

Result:

```text
PASS  fixed-epoch candidate built and strictly validated
PASS  empty dry-run left revision zero unchanged
PASS  first local deploy used no WPORG credentials and committed one atomic revision
PASS  first-deploy: exact roots, trees, bytes, and properties
PASS  identical rerun was credential-free and created no revision
PASS  identical-rerun: exact roots, trees, bytes, and properties
PASS  stale trunk/assets additions and deletions committed exactly once
PASS  stale-reconciled: exact roots, trees, bytes, and properties
PASS  property-only normalization removed transforms and restored MIME policy
PASS  property-normalized: exact roots, trees, bytes, and properties
PASS  differing-existing-tag: rejected and youngest remained 2
PASS  unknown-existing-tag-property: rejected and youngest remained 2
PASS  managed-symlink: rejected and youngest remained 2
PASS  existing-tag-externals: rejected and youngest remained 2
PASS  freshness race rejected deploy after sole competing revision 2
SVN deploy fixture suite: 15 passed, 0 failed.
```

The fixed candidate used `SOURCE_DATE_EPOCH=1700000000` and passed the existing
strict ZIP validator before any SVN scenario ran.

## Verified contract

- Empty-repository dry run returned success and kept youngest revision `0`.
- First deploy moved the repository from revision `0` to `1`, proving trunk,
  assets, and `tags/1.2.2` were committed atomically.
- Fresh checkout assertions compared the exact directory manifest and every
  file byte in trunk/tag against the candidate and assets against
  `.wordpress-org`; the recursive property maps also matched exactly.
- An identical rerun without credentials returned the explicit no-op path and
  kept revision `1`.
- A stale fixture removed canonical trunk and asset files while adding stale
  files to both trees. Deploy scheduled both additions and deletions, committed
  once, and restored exact state.
- A property-only fixture seeded `svn:eol-style`, `svn:keywords`,
  `svn:executable`, `svn:externals`, and a wrong asset MIME value. Deploy
  reported zero content add/modify/delete/replace items, normalized properties
  in one revision, and preserved exact bytes.
- A byte-different existing tag, an unknown tag property, a managed SVN
  symlink/special entry, and immutable-tag `svn:externals` each returned
  non-zero with the expected diagnostic. Youngest revision was asserted
  unchanged after every one of these failures.

## Freshness race regression

The race test stages a regular change in a separate local working copy. A
test-only `svn` wrapper intercepts the deploy's first `--show-updates` freshness
query, commits that one staged change with the real SVN binary, then delegates
the original query unchanged. It exposes no arbitrary command/eval hook to the
production deploy script.

The repository moved from revision `1` to `2` solely because of the competing
fixture commit. Deploy then rejected `remote delta modified/none at
trunk/inc/index.php`; its exit was non-zero and no third revision appeared.
This is the unavoidable race-case exception to a literal unchanged-youngest
assertion: the independently orchestrated revision must exist for freshness to
detect it, while the assertion proves deploy itself added no revision.

## Static verification

```bash
bash -n scripts/test-svn-deploy.sh
bash -n tests/svn/svn-race-wrapper.sh
python3 -c 'compile(open("tests/svn/assert-repository-state.py", encoding="utf-8").read(), "tests/svn/assert-repository-state.py", "exec")'
make -n test-svn
git diff --check
```

All passed with Subversion `1.13.0` and Python `3.8.5`. All helper and runner
files are executable. The suite's EXIT trap removed the exact temporary tree.

## Residual scope

No real WordPress.org checkout, credential test, or production commit was
performed. Hosted workflow wiring and the official dry run remain later-task
responsibilities; T21 intentionally does not change workflows.
