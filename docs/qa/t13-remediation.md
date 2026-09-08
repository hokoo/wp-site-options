# T13 release-blocking remediation evidence

## Result

`pass` — the imported runtime defects and all 41 Plugin Check errors are resolved without changing the established option name, schema, value API, or legacy hook names/arguments.

## Production changes

- `wpto_echo_field()` now starts and closes its own output buffer. The existing `wpto_echo_field` filter receives the complete captured field HTML before that trusted HTML is emitted.
- `wpto_options` is registered with `wpto_sanitize_options`. Standard declared fields use type-appropriate WordPress sanitizers; valid legacy strings and select scalar/array shapes round-trip unchanged. Unknown sections, undeclared fields, and custom field types pass through unchanged. The additive `wpto_sanitize_options` filter receives `(sanitized_options, original_input, fields)`.
- Generated field, media, attribute, and JavaScript values are escaped for their final contexts. Complete HTML supplied by the established select/custom-field/final-field/section-description extension filters remains a trusted boundary and has narrow, explained PHPCS suppressions.
- Theme-derived translation domains and WordPress core default-domain strings retain their imported semantics with narrow I18n suppressions.
- The media click binding uses jQuery `.on()` instead of the removed `.live()` API; media defaults and generated markup guard and escape their dynamic values.
- Plugin/readme license, name, short description, direct-access guards, index files, `Tested up to: 7.1`, and the 1.2.2 changelog were corrected. Imported CRLF endings in `plugin-dir/inc/media.php` and `plugin-dir/readme.txt` remain CRLF.

## Automated verification

### Composer gate

The host PHP lacks the DOM, mbstring, and XMLWriter extensions, so the exact Composer command was run in the supported PHP 8.3 WordPress CLI image with the repository mounted and the host Composer executable mounted read-only:

```bash
docker run --rm --entrypoint /usr/local/bin/composer \
  -v /usr/bin/composer:/usr/local/bin/composer:ro \
  -v /home/itron/reps/wp-site-options:/srv/web \
  -w /srv/web wordpress:cli-php8.3 check
```

Result: `pass`; PHP lint passed and PHPUnit 9.6.36 reported `27 tests, 98 assertions`.

### Real WordPress lifecycle matrix

```bash
scripts/test-integration.sh minimum
RUN_PLUGIN_CHECK=1 scripts/test-integration.sh latest
```

Results:

- minimum: WordPress 6.0 / PHP 7.4.33 — `pass`;
- latest: WordPress 7.1 / PHP 8.3.33 — `pass`;
- real WordPress sanitizers: valid values round-tripped exactly; malicious/malformed standard values were sanitized; custom/unknown values and all three final filter arguments were preserved;
- Plugin Check 1.9.0 update mode: `0 ERROR`, `4 WARNING`, exit `0`.

Local diagnostic evidence was preserved by the integration runner under ignored paths:

- `tests/integration/artifacts/minimum-20260908T150434Z-2599/`
- `tests/integration/artifacts/latest-20260908T150052Z-99236/`

### Authenticated browser gate

A clean, uniquely scoped `wp-site-options-t13-smoke` Compose project used WordPress/PHP 8.3 on `http://wp-site-options.local:18093` and project-owned database/WordPress volumes. The unchanged T12 assertion was run with:

```bash
WP_HOST=wp-site-options.local \
WP_HTTP_PORT=18093 \
WP_ADMIN_USER=admin \
WP_ADMIN_PASSWORD='<local ephemeral credential>' \
npm run test:e2e
```

Result: `1 passed`. The test signed in, rendered Settings → Reading, saved and reloaded all representative fields, and found no browser console, uncaught page, or visible PHP errors. WP-CLI confirmed:

```json
{"local_fixture":{"headline":"Authenticated browser smoke","featured":"1","items_per_page":"17"}}
```

The WordPress `debug.log` was empty. The project-owned containers, network, and volumes were removed after verification; unrelated Docker resources were not touched.

## Residual Plugin Check warnings

| Count | Finding | Disposition |
|---:|---|---|
| 1 | `WordPress.DB.SlowDBQuery.slow_db_query_meta_key` in the optional media post-meta path | Nonblocking heuristic. The query uses WordPress metadata APIs and changing its storage/query contract is outside this maintenance release. |
| 2 | `trademarked_term` for plugin name `WP Site Options` in the plugin header/readme | Existing WordPress.org identity; renaming is a product/branding and compatibility decision, not a security fix. |
| 1 | `trademarked_term` for slug `wp-site-options` | Existing repository/plugin directory identity; changing it would break deployment and update identity. |

The trusted raw-HTML extension filters and the final sanitizer filter remain intentionally powerful developer boundaries. They are documented, regression-tested with their existing arguments, and must only be used by trusted plugin/theme code.
