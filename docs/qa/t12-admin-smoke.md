# T12 authenticated admin smoke evidence

## Result

`fail` — the browser harness is complete and the critical persistence path works, but it exposes a release-blocking PHP notice in production plugin code. The assertion remains active for T13; the gate has not been weakened or skipped.

## Environment

- URL: `http://wp-site-options.local:18092` (temporary project-scoped port)
- Compose project: `wp-site-options-t12-smoke`
- WordPress image: `wordpress:php8.3-apache`
- PHP: 8.3
- Browser runner: Playwright 1.59.0, headless Chromium
- Browser hostname resolution: Chromium maps `wp-site-options.local` to `127.0.0.1`

No administrator password is recorded in this evidence. The test read credentials from the ignored `.env` file.

## Verified critical path

The automated smoke completed these steps before the error assertion:

1. Signed in through `/wp-login.php` as the configured administrator.
2. Opened `/wp-admin/options-reading.php` using the `wp-site-options.local` hostname.
3. Found the `Local development options` section.
4. Confirmed that `headline`, `featured`, and `items_per_page` were visible.
5. Saved deterministic values and waited for the WordPress settings-updated redirect.
6. Reloaded Reading Settings and confirmed the values remained in the controls.

WP-CLI independently confirmed the saved option payload:

```json
{"local_fixture":{"headline":"Authenticated browser smoke","featured":"1","items_per_page":"17"}}
```

The browser collector reported no console errors and no uncaught page errors. External host requests were fulfilled locally by the test, so the scenario did not depend on network access after npm and Chromium installation.

## Release-blocking finding

The final PHP-error assertion failed reproducibly with:

```text
Notice: ob_end_clean(): Failed to delete buffer. No buffer to delete in /srv/web/plugin-dir/inc/fields.php on line 172
```

Critical path:

```text
authenticated wp-admin
  → Settings → Reading
  → local_fixture headline rendering
  → wpto_echo_field()
  → plugin-dir/inc/fields.php:172
```

The production renderer reads and closes an output buffer without establishing that buffer in this function. The visible notice violates T12's no-PHP-errors gate even though the values persist successfully.

## Reproduction

With the local site configured and running:

```bash
npm ci
npm run test:e2e:install
make setup
npm run test:e2e
```

Expected current result: one failing test with the notice above. Failure-only screenshot and trace artifacts are written beneath ignored `test-results/e2e/`.

T13 must correct the production output-buffer handling and rerun this same assertion. Do not suppress the notice, disable `WP_DEBUG`, or relax the browser gate.
