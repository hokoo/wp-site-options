# WordPress integration testing

The integration suite runs against a real, clean WordPress database and filesystem in project-scoped Docker volumes. It allocates no host port and uses a unique Compose project name for every invocation, so it does not reuse or remove the normal local-development stack.

Host prerequisites are Docker with Compose v2, Bash, `grep`, and `jq` (`jq` is required by the Plugin Check command).

## Profiles

```bash
scripts/test-integration.sh minimum
scripts/test-integration.sh latest
scripts/test-integration.sh all
```

- `minimum` downloads WordPress 6.0 and runs it with PHP 7.4.
- `latest` downloads the current stable WordPress and runs it with PHP 8.3.
- `all` runs both profiles sequentially.

Each profile verifies clean activation, the fixture section and fields on the Reading settings page, Settings API registration, and an option database/public-API round trip. Diagnostic evidence is written under `tests/integration/artifacts/`. Compose logs and `wp-content/debug.log` are collected even when a command fails. The uniquely named containers, network, and volumes are removed by default; set `KEEP_INTEGRATION_ENV=1` only when interactive investigation is required.

## Release candidate input

The source tree is symlinked by default. Once the release builder is available, pass its installable ZIP without changing the suite:

```bash
PLUGIN_ZIP=/absolute/path/to/wp-site-options.zip scripts/test-integration.sh all
```

The candidate is copied into the clean container, installed through `wp plugin install`, activated, and subjected to the same assertions. The suite deliberately does not build or synthesize a candidate.

## Plugin Check

Run the pinned Plugin Check version in a clean latest-profile site:

```bash
scripts/plugin-check.sh
```

Override `PLUGIN_CHECK_VERSION` deliberately when evaluating an upgrade. Strict JSON, stderr, WordPress debug output, and Compose logs are retained in the run's artifact directory. The command exits non-zero for Plugin Check errors or malformed output.
