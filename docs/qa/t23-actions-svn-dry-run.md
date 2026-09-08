# T23 Actions configuration and real SVN dry-run evidence

## Result

PASS. The repository-side GitHub Actions configuration is available with the
intended least-privilege boundaries, the post-fix branch CI run completed all
eight jobs successfully, and a fresh read-only dry-run against the official
WordPress.org SVN repository produced only the expected `1.2.2` delta. No tag,
GitHub Release, credentialed SVN operation, or SVN commit was created.

Evidence date: 2026-09-09. Source commit:
`c319293833119ff7dd3b15823ff6dece5aeaaa61`.

## GitHub configuration

- The repository default branch is `master`.
- Default workflow permissions are read-only; workflows and jobs declare
  `contents: read`, except the GitHub Release publisher's narrowly scoped
  `contents: write` permission.
- Active workflows include `CI` and the tag-driven `Release` workflow.
- Repository variable `WPORG_USERNAME` exists and is non-empty. Its value was
  not printed or recorded.
- Repository secret `WPORG_PASSWORD` exists. GitHub exposes its name but not its
  value; no attempt was made to retrieve or log the value.
- The `wordpress-org` environment exists and accepts only custom deployment tag
  policies. Its two policies are `v[0-9]*.[0-9]*.[0-9]*` and
  `v-[0-9]*.[0-9]*.[0-9]*`.
- The variable and secret are repository-scoped, not duplicated at environment
  scope. The workflow references them only in the final production deploy step,
  inside the `wordpress-org` environment job.
- There is no required reviewer or wait timer. Release serialization, tag
  validation, `master` ancestry, artifact verification, and the environment tag
  policies remain the automated production boundaries.

Hosted post-fix CI run
[`34287085705`](https://github.com/hokoo/wp-site-options/actions/runs/34287085705)
completed successfully. All eight jobs passed:

- `PHP quality / PHP 7.4`;
- `PHP quality / PHP 8.3`;
- `WordPress integration / minimum`;
- `WordPress integration / latest`;
- `Plugin Check`;
- `Authenticated admin smoke`;
- `Release contracts`;
- `Release candidate`.

This confirms that the scoped `subversion` installation fixed the runner issue
seen in the preceding run. It does not substitute for the deliberately deferred
real tag-event publication test.

## Candidate and official repository baseline

The candidate was built from the source commit above with
`SOURCE_DATE_EPOCH=1788907220` and passed the strict release ZIP validator.

```text
artifact: dist/wp-site-options.zip
version: 1.2.2
sha256: 5479aef0dbba0b32b9f4935129bcaa00dbb5b80c77aa5e2cdb042b9e1e055640
```

The read-only target was the official repository
`https://plugins.svn.wordpress.org/wp-site-options`, UUID
`b8457f37-d9ea-0310-8a92-e5e31aec5664`. The plugin subtree's latest log
revision was `3283155` before and after the check. The fresh working copy was at
global repository revision `3687359`; the difference between those two values
is normal for a subtree checkout.

## Sanitized dry-run delta

```text
-P assets/banner-1544x500.jpg
-P assets/banner-772x250.jpg
-P assets/icon-128x128.jpg
-P assets/icon-256x256.jpg
-P assets/screenshot-1.png
-P assets/screenshot-2.png
A- tags/1.2.2
M- tags/1.2.2/inc/classes.php
M- tags/1.2.2/inc/fields.php
M- tags/1.2.2/inc/index.php
M- tags/1.2.2/inc/media.php
M- tags/1.2.2/inc/settings.php
M- tags/1.2.2/index.php
M- tags/1.2.2/readme.txt
M- tags/1.2.2/wp-site-options.php
M- trunk/inc/classes.php
M- trunk/inc/fields.php
M- trunk/inc/index.php
M- trunk/inc/media.php
M- trunk/inc/settings.php
M- trunk/index.php
M- trunk/readme.txt
M- trunk/wp-site-options.php
```

The six `-P` entries are the expected MIME-property normalization of existing
WordPress.org assets. `A- tags/1.2.2` is the new immutable release directory;
the eight files below it are its copied candidate contents. The same eight
candidate files replace the current `trunk` contents. There are no file
deletions, replacements, or unexplained additions.

```text
added=1 modified=16 deleted=0 replaced=0 property_modified=6 total=23
```

The script completed in dry-run mode at working-copy revision `3687359`. The
official plugin subtree remained at revision `3283155`, proving that no commit
was attempted. No SVN credentials were supplied to the dry-run.

## Deferred production evidence

The first approved production tag must still prove the tag-push event,
GitHub Release publication, artifact handoff, credential resolution within the
environment job, and final WordPress.org commit path. Those external mutations
belong to T26 and require explicit human production approval.
