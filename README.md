# WP Site Options

WordPress plugin for declaring theme/site options on the standard **Settings → Reading** screen.

The canonical installable plugin source lives in [`plugin-dir/`](./plugin-dir/). WordPress.org banners, icons, and screenshots live in [`.wordpress-org/`](./.wordpress-org/) and are not included in the plugin ZIP.

## Delivery status

The repository is being initialized from the current WordPress.org SVN trunk. The approved delivery plan and execution backlog are available in [`docs/`](./docs/).

Local development, automated tests, reproducible release archives, and tag-driven WordPress.org deployment will be added through the tracked delivery backlog.

## Public API

Existing integrations use the global `$wpto` object and its field declarations. Public hooks, option keys, and behavior are treated as compatibility contracts during the maintenance migration.

## License

GPL-2.0-or-later, matching the WordPress.org plugin metadata.
