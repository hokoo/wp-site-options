# E6 post-release QA for WP Site Options 1.2.2

Date: 2026-09-09
Production source: `ed1aa25682453c049fe80330019eb4ddadcd0c7d`
Production tag: `v1.2.2`
GitHub Actions run: `34290682147`
WordPress.org revision: `3687381`
Verdict: **PASS**

## Scope and safety

This was an independent post-release check of the already published artifacts.
QA made no Git, GitHub, or SVN mutation and did not read or print credential
values. All GitHub and WordPress.org access was anonymous and read-only. Docker
tests used unique Compose project names and removed their own containers,
networks, and volumes.

Raw integration/Compose/debug output was retained only in the QA temporary
directory while tests ran. Inspection output was reduced to boolean results
and counts; the temporary directory was removed after this report was written.

## Published GitHub Release and workflow

Anonymous GitHub API metadata and fresh downloads were checked from:

- [GitHub Release v1.2.2](https://github.com/hokoo/wp-site-options/releases/tag/v1.2.2)
- [GitHub Actions run 34290682147](https://github.com/hokoo/wp-site-options/actions/runs/34290682147)

Evidence:

```text
release_id=385124578
target_commitish=master
draft=false
prerelease=false
assets=wp-site-options.zip,wp-site-options.zip.sha256

wp-site-options.zip:
  size=11577
  service digest=sha256:eb031e18e680413524be38cfb533afd438f357b2f1693627f9bbcd92838fb8f9
wp-site-options.zip.sha256:
  size=86
  service digest=sha256:69a8072b1f6b1785b3cb0570214e6c4b1463de0b0689a21aff6c753bbae3daac

checksum file lines=1
sha256sum -c=PASS
inner ZIP SHA-256=eb031e18e680413524be38cfb533afd438f357b2f1693627f9bbcd92838fb8f9
```

There were exactly two Release assets, both in `uploaded` state. The checksum
file names the ZIP correctly, and its inner digest equals both the expected
release checksum and GitHub's asset-service digest.

`v1.2.2` is an annotated tag object
`f2523b16255c6289fe0e22b698b4a474dea2c7ca`; dereferencing it yields exactly
`ed1aa25682453c049fe80330019eb4ddadcd0c7d`.

The workflow run is a completed successful tag-push attempt on that same
commit. Public metadata reports 11/11 jobs successful, including GitHub Release
publication and WordPress.org deployment. Sanitized step metadata contained
101 steps: 97 successful and four expected conditionally skipped diagnostic
steps; the WordPress.org job had 11/11 successful steps.

The downloaded ZIP passed the strict validator for `1.2.2`. Rebuilding from
the tagged source with `SOURCE_DATE_EPOCH=1788909676` produced a byte-identical
ZIP (`cmp` passed) with the same SHA-256. Its manifest has one canonical plugin
root, two directories, and 11 files.

Representative commands:

```bash
curl --fail --location \
  https://github.com/hokoo/wp-site-options/releases/download/v1.2.2/wp-site-options.zip \
  -o /tmp/.../wp-site-options.zip
curl --fail --location \
  https://github.com/hokoo/wp-site-options/releases/download/v1.2.2/wp-site-options.zip.sha256 \
  -o /tmp/.../wp-site-options.zip.sha256
( cd /tmp/... && sha256sum -c wp-site-options.zip.sha256 )
SOURCE_DATE_EPOCH=1788909676 \
  scripts/validate-release-zip.sh /tmp/.../wp-site-options.zip 1.2.2
SOURCE_DATE_EPOCH=1788909676 \
  scripts/build-release-zip.sh /tmp/.../local-rebuild.zip
cmp /tmp/.../wp-site-options.zip /tmp/.../local-rebuild.zip
```

## Official WordPress.org SVN state

A fresh anonymous checkout of
`https://plugins.svn.wordpress.org/wp-site-options` was compared recursively
with the unpacked GitHub Release and the tagged Git asset source.

```text
working-copy revision=3687384
plugin subtree last-changed revision=3687381
repository UUID=b8457f37-d9ea-0310-8a92-e5e31aec5664

candidate entries=13 (11 files)
trunk byte differences=0
tags/1.2.2 byte differences=0
asset entries=6
asset byte differences=0
SVN status entries=0

trunk property nodes=1
tag property nodes=1
asset property nodes=6
unexpected properties=0
```

The one plugin property node in each installable tree is the expected `.mo`
`svn:mime-type=application/octet-stream`; all six asset nodes have their exact
image MIME types. There are no transforming or unknown properties.

The sanitized `r3687381` XML log has the exact message
`Release wp-site-options 1.2.2` and 23 changed paths: six under `assets`, nine
under `tags`, and eight under `trunk`. No path is outside the plugin subtree.

Representative commands:

```bash
svn checkout --quiet --ignore-externals --non-interactive --no-auth-cache \
  https://plugins.svn.wordpress.org/wp-site-options /tmp/.../svn-wc
svn proplist --xml --verbose -R /tmp/.../svn-wc/trunk
svn proplist --xml --verbose -R /tmp/.../svn-wc/tags/1.2.2
svn proplist --xml --verbose -R /tmp/.../svn-wc/assets
svn status --xml --no-ignore /tmp/.../svn-wc
svn log --xml -v -r 3687381 --non-interactive --no-auth-cache \
  /tmp/.../svn-wc
```

## Published ZIP install and lifecycle

The freshly downloaded GitHub Release ZIP was supplied through `PLUGIN_ZIP`
to two clean, project-scoped real WordPress environments:

```bash
PLUGIN_ZIP=/tmp/.../wp-site-options.zip \
  WP_SITE_OPTIONS_IT_ARTIFACTS=/tmp/.../integration-artifacts \
  scripts/test-integration.sh minimum

PLUGIN_ZIP=/tmp/.../wp-site-options.zip \
  WP_SITE_OPTIONS_IT_ARTIFACTS=/tmp/.../integration-artifacts \
  scripts/test-integration.sh latest
```

Results:

| Profile | WordPress | PHP | Plugin | Lifecycle/settings/API | Debug PHP errors | Resources after cleanup |
| --- | --- | --- | --- | --- | ---: | ---: |
| minimum | 6.0 | 7.4.33 | 1.2.2 | pass | 0 | 0 |
| latest | 7.1 | 8.3.33 | 1.2.2 | pass | 0 | 0 |

Each profile installed and activated the ZIP, confirmed active state, registered
the representative Reading settings section and its three fields, registered
the legacy option name and sanitizer, round-tripped settings through the
database/public API, preserved supported legacy/custom value shapes, and
passed sanitizer/filter contracts. Both debug logs had zero non-empty lines;
Compose logs had zero PHP fatal/parse markers.

## Public update from 1.2

The previous public
`https://downloads.wordpress.org/plugin/wp-site-options.1.2.zip` was installed
and activated in another isolated latest-profile site. A nested marker was
written to `wpto_options`, WordPress update transients were cleared, and the
normal `wp plugin update wp-site-options` path was invoked.

```text
old version=1.2
new version=1.2.2
active after update=true
marker option persisted=true
WordPress=7.1
PHP=8.3.33
debug non-empty lines=0
debug PHP error count=0
resources after cleanup=0
```

This confirms both public update discovery and settings persistence across the
1.2 to 1.2.2 transition.

## WordPress.org propagation

Propagation is complete; it is not a blocker:

- the [public plugin page](https://wordpress.org/plugins/wp-site-options/)
  exposes version `1.2.2`;
- the Plugins API returns slug `wp-site-options`, version `1.2.2`, and a
  versioned `1.2.2` download link;
- the public `wp-site-options.1.2.2.zip` has plugin header `Version: 1.2.2`;
- all 11 files extracted from the WordPress.org ZIP are byte-identical to the
  GitHub Release installable content.

The WordPress.org-generated archive SHA-256 is
`36b7daaeead0e1f7f1ba5545efeb1d9f759e93a2d34313ca84cb7f76ea5a8f1e`.
It differs from the deterministic GitHub ZIP because WordPress.org repackages
the SVN tree; the extracted file manifest and bytes, which are the installable
contract, are identical.

Regional page/CDN caches can still lag temporarily after publication, but the
authoritative Plugins API, public page, versioned download, and updater all
resolved `1.2.2` during this QA.

## Canonical source and closure

The release runbook identifies Git `master` as the canonical source, requires
future work to begin on a feature branch and reach `master` through a pull
request, and marks the legacy Windows SVN working copy as read-only reference
material. Local `master`, `origin/master`, and dereferenced `v1.2.2` all pointed
to the published commit when QA began. Worktree activity later moved to a
feature branch without changing plugin source, consistent with that policy.

## Defects and residual risks

No release defect, unexplained artifact difference, PHP regression, update
failure, or propagation blocker was found. No human risk acceptance is needed
for this verdict.

Normal residual operational constraints remain: WordPress.org release tags are
immutable, an already published artifact cannot be rolled back by moving the
Git tag, and future fixes require a new patch release. These are documented
release constraints rather than T27 defects.
