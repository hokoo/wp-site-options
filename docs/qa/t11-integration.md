# T11 WordPress integration and Plugin Check evidence

Date: 2026-09-08
Source commit tested: `23bf350` plus the uncommitted T11 integration harness
Plugin version: `1.2.2`

## Lifecycle matrix

| Profile | WordPress | PHP | Result | WordPress debug log |
|---|---:|---:|---|---|
| minimum | 6.0 | 7.4.33 | pass | empty |
| latest at execution time | 7.1 | 8.3.33 | pass | empty |

Both clean, project-scoped runs verified:

- plugin installation from the canonical `plugin-dir/` source and clean activation;
- the `admin_init` priority-50 registration contract;
- the `local_fixture` section and three representative fields on the real Reading Settings API;
- the literal `wpto_options` and `wpto_settings` names;
- database persistence and raw/filtered public API reads for text, checkbox, and number values;
- removal of only the uniquely named containers, network, and volumes created by each run.

Commands:

```bash
scripts/test-integration.sh minimum
scripts/test-integration.sh latest
```

The first latest attempt exposed WP-CLI's 128 MiB extraction limit for WordPress 7.1. The runner now invokes WP-CLI with a 512 MiB limit. A second infrastructure-only failure showed that the latest MariaDB client requests TLS against the isolated database; `wp db check --skip-ssl` is now explicit. Both failed attempts preserved their diagnostic directories and cleaned their project-scoped Docker resources.

## Initial Plugin Check report

Command:

```bash
scripts/plugin-check.sh
```

Environment: WordPress 7.1, PHP 8.3.33, Plugin Check 1.9.0. The lifecycle portion passed and its WordPress debug log was empty. Plugin Check itself completed successfully and returned valid strict JSON with **41 errors and 5 warnings**; the wrapper therefore exited non-zero as designed. These findings are remediation input, not a T11 infrastructure failure.

| Severity | Code | Count |
|---|---|---:|
| ERROR | `WordPress.Security.EscapeOutput.OutputNotEscaped` | 23 |
| ERROR | `WordPress.Security.EscapeOutput.UnsafePrintingFunction` | 1 |
| ERROR | `WordPress.WP.I18n.MissingArgDomain` | 6 |
| ERROR | `WordPress.WP.I18n.NonSingularStringLiteralDomain` | 4 |
| ERROR | `Generic.PHP.DisallowShortOpenTag.Found` | 2 |
| ERROR | `PluginCheck.CodeAnalysis.SettingSanitization.register_settingMissing` | 1 |
| ERROR | `WordPress.WP.AlternativeFunctions.rand_rand` | 1 |
| ERROR | `missing_direct_file_access_protection` | 1 |
| ERROR | `outdated_tested_upto_header` | 1 |
| ERROR | `plugin_header_no_license` | 1 |
| WARNING | `WordPress.DB.SlowDBQuery.slow_db_query_meta_key` | 1 |
| WARNING | `mismatched_plugin_name` | 1 |
| WARNING | `readme_parser_warnings_trimmed_short_description` | 1 |
| WARNING | `trademarked_term` | 2 |

The main actionable groups are output escaping, translation domain usage, Settings API sanitization, direct-access protection, short opening tags, `rand()`, and release metadata. The trademark findings concern the established WordPress.org slug/name and need risk classification rather than an automatic rename. The `meta_key` warning is heuristic: the flagged value is an argument name passed to `metadata_exists()`/`get_post_meta()`, not a direct custom SQL query.

Machine-readable strict JSON and all raw logs are retained by the local run under the ignored `tests/integration/artifacts/` tree. This tracked report records the exact environment and aggregated evidence without committing ephemeral container logs.

## Candidate ZIP readiness

The runner accepts `PLUGIN_ZIP=/absolute/path/to/wp-site-options.zip`. It copies the supplied artifact into a clean container and installs it with `wp plugin install --force` before running the same activation and lifecycle assertions. This path was not executed because T17 has not produced a candidate yet; no substitute ZIP was fabricated.
