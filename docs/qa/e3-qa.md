# E3 independent QA report

- Date: 2026-09-08
- Result: **PASS**
- Source HEAD: `768d92f10ce0bad8ef3fbdbb89363c1796e4582b`
- T13 production change reviewed: `4e42760..acb6b53`
- CI implementation reviewed: `9c1bd3857f9da2e1bfe7fb3587807bd0e6c348bf`

## T9-T10: deterministic tooling and public contract tests

`composer validate --strict --no-interaction` passed on PHP 7.4. Independent read-only container runs of `composer check` passed on both supported PHP profiles:

| PHP | PHPUnit | Result |
|---:|---:|---|
| 7.4.33 | 9.6.36 | `27 tests, 98 assertions` |
| 8.3.33 | 9.6.36 | `27 tests, 98 assertions` |

Both runs linted all production and test PHP before PHPUnit. `composer.json`, `composer.lock`, `package.json`, and `package-lock.json` are tracked; development dependencies remain outside `plugin-dir/`.

The suite covers bootstrap globals, public class/property and option names, hook registration/arguments, raw/default/filtered/gallery reads, field registration/rendering, imported edge cases, metadata, media output, and sanitization.

A controlled mutation was made only in a copied source tree under `/tmp`: `wpto_options` was changed to `wpto_options_qa_broken`. The complete unit suite exited `1` with exactly the expected `BootstrapContractTest` failure (`expected wpto_options; actual wpto_options_qa_broken`). The repository source was never modified. A subsequent clean-source `composer check` passed again with `27 tests, 98 assertions`.

## T11: real WordPress integration and Plugin Check

Independent runs used unique Compose project names, clean database/WordPress volumes, and automatic project-scoped cleanup:

| Profile | WordPress | PHP | Result | `debug.log` |
|---|---:|---:|---|---:|
| minimum | 6.0 | 7.4.33 | pass | 0 bytes |
| latest | 7.1 | 8.3.33 | pass | 0 bytes |

Both profiles verified clean installation and activation, `wpto_options`/`wpto_settings`, priority-50 Settings API registration, the fixture section and three fields, database round-trip, raw/filtered reads, and expected string value types. The lifecycle assertions also proved that valid standard legacy values retain their shapes and that custom field values and undeclared fields pass through sanitization unchanged.

Plugin Check ran independently on WordPress 7.1 / PHP 8.3.33 with pinned Plugin Check `1.9.0`. It exited `0`, stderr was empty, and strict JSON contained `0 ERROR` and `4 WARNING`:

| Count | Code | Classification |
|---:|---|---|
| 1 | `WordPress.DB.SlowDBQuery.slow_db_query_meta_key` | Nonblocking heuristic for the optional `meta_key` path implemented through core metadata APIs; no direct custom SQL is used. |
| 3 | `trademarked_term` | Two plugin-name findings and one slug finding for the established WordPress.org `WP Site Options` / `wp-site-options` identity. Renaming is a product, update-identity, and compatibility decision rather than a maintenance security fix. |

## T12: authenticated browser smoke

A clean Compose project `wpsoe3qa768d92f` ran WordPress/PHP 8.3 at `http://wp-site-options.local:49219`. All three services were healthy, the plugin was active, and its symlink resolved to `/srv/web/plugin-dir`.

The controlled authentication negative used an incorrect ephemeral password and wrote failure artifacts only under `/tmp`. Playwright exited `1` at the login gate because navigation never reached `/wp-admin/`, proving that the smoke cannot pass without authentication.

The immediately following clean run used the correct ignored local credentials and passed (`1 passed`, 5.1 seconds). It authenticated, opened Settings -> Reading, found all three fixture controls, saved/reloaded them, and verified:

```json
{"local_fixture":{"headline":"Authenticated browser smoke","featured":"1","items_per_page":"17"}}
```

The unchanged test found no console errors, uncaught page errors, visible PHP warning/notice/fatal text, or critical-error screen. WordPress `debug.log` was independently checked and was 0 bytes.

The browser project's containers, network, database volume, `local-dev/`, and QA-created `.env` were removed. The unrelated `aws-polly` containers retained IDs `11beee3aa768`, `a75aef9d5a0b`, and `d31a4402a6e6` and remained running.

## T13: remediation and public API boundary

The `4e42760..acb6b53` production diff is scoped to direct-access guards, output-buffer ownership, escaping, type-aware sanitization, media compatibility, and release metadata. Static comparison plus unit and real-WordPress assertions confirmed preservation of:

- globals `$wpto`, `$wpto_url`, and `$wpto_path`;
- class `wpto\Theme_options` and public properties `$fields`, `$options`, `$plugin_options_name`, `$plugin_settings_name`, and `$text_domain`;
- literal option/settings names `wpto_options` and `wpto_settings`;
- legacy callable names and signatures: `getOption`, `wpto_getoption`, `wpto_menu_init`, `wpto_setting_section_before`, `wpto_echo_attrs`, `wpto_echo_field`, `wpto_media_modal`, and `wpto_media_load`;
- actions `admin_init` at priority 50, `admin_footer` at priority 100, `wpto_before()` and `wpto_after()` with no explicit arguments;
- filters and argument counts: `wpto_getoption` (3), dynamic `wpto_settings_header__<section>` (2), `wpto_setting_section_before` (2), `wpto_setCustomValidity_text` (2), `wpto:select_options` (3), `wpto_echo_custom_field` (4), and `wpto_echo_field` (4).

`wpto_sanitize_options($input)` and its 3-argument filter are additive. Unit and integration tests confirm standard-field sanitization while preserving valid scalar/array forms, custom field payloads, unknown sections/fields, and the final filter arguments. The existing `inc/functions.php` value-filter implementation did not change.

The plugin display header was aligned with the existing readme name, while the directory slug, runtime theme-derived `$text_domain`, option schema, and callable/hook identifiers remained unchanged. The resulting identity warnings are classified above rather than hidden.

## T14: CI workflow and hosted proof

Static inspection of `.github/workflows/ci.yml` confirmed:

- triggers only for pushes to `master` and the documented pull-request events targeting `master`;
- the same draft-PR exclusion on every quality job;
- top-level `contents: read` only, with no write permission, release credential, `secrets.*`, WPORG, push, or release reference;
- concurrency grouped by workflow plus PR number/ref, cancelling only superseded PR runs;
- failure diagnostics for integration and Plugin Check, and browser ordering of `always()` diagnostics -> `always()` cleanup -> failure-only upload;
- four job definitions expanding to the six stable required-check names;
- every external Action pinned to a full 40-character SHA.

The five distinct SHA pins were independently matched to their official Git tags with `git ls-remote`: `actions/checkout@v7.0.1`, `actions/setup-node@v7.0.0`, `actions/cache@v6.1.0`, `actions/upload-artifact@v7.0.1`, and `shivammathur/setup-php@2.37.2`.

The public GitHub API independently confirmed [CI run #1](https://github.com/hokoo/wp-site-options/actions/runs/34245358238): push to `master`, head SHA `9c1bd3857f9da2e1bfe7fb3587807bd0e6c348bf`, completed with `success`. Its job API returned exactly six jobs, all successful:

- `PHP quality / PHP 7.4`;
- `PHP quality / PHP 8.3`;
- `WordPress integration / minimum`;
- `WordPress integration / latest`;
- `Plugin Check`;
- `Authenticated admin smoke`.

The controlled unit and browser-auth negatives both returned non-zero through the same underlying commands used by CI. The clean commands then passed, demonstrating fail-closed gates and local/hosted parity.

## Defects and residual risks

No E3 defects or public API regressions were found. No new risk acceptance is required.

The four nonblocking Plugin Check warnings remain intentionally documented. The hosted run proves the push-to-`master` path; pull-request draft transitions and cancellation behavior were independently inspected in workflow logic but were not exercised by creating a temporary remote PR. Browser coverage remains the approved single Chromium smoke rather than a cross-browser matrix.
