# Authenticated admin smoke

The Playwright smoke signs in to the local WordPress admin, opens **Settings → Reading**, verifies the three `local_fixture` fields, saves deterministic values, reloads the page, and verifies persistence. It also fails on browser console errors, uncaught page errors, or visible PHP error output.

## Install once

```bash
npm ci
npm run test:e2e:install
```

After this installation, the test itself does not need external network access. Requests to hosts other than the configured local WordPress hostname are fulfilled locally with an empty response.

## Run

Start or reconcile the local site first, then execute the smoke:

```bash
make setup
make test-e2e
```

The test reads `WP_HOST`, `WP_HTTP_PORT`, `WP_ADMIN_USER`, and `WP_ADMIN_PASSWORD` from the process environment first and the ignored root `.env` second. Defaults match `.env.example`. Credentials are used only to fill the login form and are not printed by the test.

Chromium maps `wp-site-options.local` (or the configured `WP_HOST`) directly to `127.0.0.1`, so automated runs do not require changing a hosts file. The browser still uses the configured hostname in the URL.

On success, no screenshot or trace is retained. On failure, diagnostic output is written under the ignored `test-results/e2e/` directory; Playwright keeps a screenshot and trace for the failing test only.
