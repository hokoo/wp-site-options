# WP Site Options

WordPress plugin for declaring theme/site options on the standard **Settings → Reading** screen.

The canonical installable plugin source lives in [`plugin-dir/`](./plugin-dir/). WordPress.org banners, icons, and screenshots live in [`.wordpress-org/`](./.wordpress-org/) and are not included in the plugin ZIP.

## Delivery status

GitHub `master` is the canonical development source. The repository includes a
Docker local environment, automated compatibility and browser tests,
reproducible release archives, and tag-driven GitHub/WordPress.org deployment.
The first automated production release remains subject to explicit maintainer
approval.

See [local development](docs/development.md), the [release runbook](docs/release.md),
and the [execution backlog](docs/execution-backlog.md).

## Public API

Existing integrations use the global `$wpto` object and its field declarations. Public hooks, option keys, and behavior are treated as compatibility contracts during the maintenance migration.

## License

GPL-2.0-or-later, matching the WordPress.org plugin metadata.
