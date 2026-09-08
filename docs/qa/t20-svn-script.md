# T20 WordPress.org SVN deployment script evidence

Date: 2026-09-09
Source commit: `4dd99d964266de80aa8833eff1c20c3e4588df6b`
Plugin version: `1.2.2`
Candidate `SOURCE_DATE_EPOCH`: `1788902412`

## Result

Local implementation smoke passes. No WordPress.org commit was attempted.

## Static checks

```bash
bash -n scripts/deploy-wordpress-svn.sh
scripts/deploy-wordpress-svn.sh --help
git diff --check -- scripts/deploy-wordpress-svn.sh \
  docs/wordpress-svn-deploy.md docs/qa/t20-svn-script.md
```

All commands passed. The new script is executable. The smoke environment used
Subversion `1.13.0` and Python `3.8.5`.

## Isolated local SVN smoke

A repository and candidate ZIP were created below one `mktemp` directory. The
script was then run against its `file:///` URL in three modes:

1. dry run from an empty revision-zero repository;
2. local fixture commit;
3. identical repeat without credentials.

Observed results:

- strict ZIP validation passed for each invocation;
- dry run reported `36` scheduled entries, including the local trunk-to-tag
  copy and eight MIME property changes, then confirmed revision `0` unchanged;
- the local commit created trunk, assets, and `tags/1.2.2` in one revision;
- C-locale commit output yielded repository revision `1`; the untouched local
  tree remained clean and exact without a post-commit update;
- the repeat produced a clean XML status and exited through the credential-free
  no-op path;
- a seeded legacy-asset fixture produced six legitimate `normal`/
  property-modified XML entries, all reported as `-P`, while dry run kept its
  repository at revision `2`;
- a deliberately changed existing tag failed on byte comparison before trunk
  synchronization; a separate trunk sentinel remained in repository revision
  `2`, proving that no deploy commit or overwrite occurred;
- a trunk fixture with one missing canonical file and one unexpected file was
  converted from XML status into one scheduled add and one scheduled delete;
  dry run reported `added=1`, `deleted=1`, `total=2` and kept revision `2`;
- the resulting repository tree contained exactly the expected managed roots;
- clean-checkout byte comparisons passed for representative trunk, tag, and
  asset files; JPEG, PNG, and `.mo` MIME properties matched the documented
  values, and no transforming property was present;
- the pre-exit freshness gate successfully queried managed paths and the tags
  ancestor against repository HEAD in both dry-run and commit paths;
- a concurrent revision changing `trunk/inc/index.php` after checkout was
  rejected as `remote delta modified/none`; deploy exited non-zero and the only
  new repository revision was the independently seeded race commit;
- an unknown property on an otherwise byte-identical existing tag and an
  official URL derived from a noncanonical slug were both rejected before
  synchronization or network commit;
- the EXIT trap removed the isolated fixture.

The first dry-run property count includes MIME properties on six assets and the
`.mo` file in both trunk and the newly copied tag.

## Scope boundary

This smoke confirms the positive empty-repository, commit, idempotent,
property-only, and basic existing-tag collision paths. The comprehensive
malicious-path, credentials, status, and byte-preservation matrix belongs to
T21. A real official dry run and any WordPress.org commit remain explicitly
outside this evidence.
