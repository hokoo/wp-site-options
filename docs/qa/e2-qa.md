# E2 independent QA report

- Date: 2026-09-08
- Result: **PASS**
- Reviewed commits: `49b8cfc` (Compose stack), `23bf350` (local setup), `e43a1c0` (command interface and development guide)
- QA Compose project: `wsoqa-e2-20260908-1740`
- QA URL: `http://wp-site-options.local:49188`
- Images: `wordpress:php8.3-apache`, `wordpress:cli-php8.3`, `mariadb:10.11`

## Evidence

### Static configuration and documentation

- `docker compose config --quiet` passed.
- Resolved configuration contained only `db`, `wordpress`, and `wp-cli`; the published port was `127.0.0.1:49188`; the database volume was `wsoqa-e2-20260908-1740_db-data`.
- `make` used the safe `help` default and listed `setup`, `up`, `down`, `reset`, `logs`, `shell`, `lint`, and `test`.
- `make -n setup up down reset shell test lint` resolved each documented target to the expected script, Compose, or Composer command.
- `bash -n scripts/setup-local.sh scripts/reset-local.sh` passed.
- `docs/development.md` documents WSL2 Docker Desktop integration, native Linux daemon access, Windows/Linux hosts-file locations, configurable ports, persistent stores, exact symlink targets, and permission/symlink troubleshooting. It does not claim to modify the hosts file automatically.

### Clean setup and runtime state

- Before setup, `.env` and `local-dev/` were absent. The QA `.env` used a unique project name and a previously unused high port.
- `make setup` created only the QA network, database volume, and three QA containers. All services reached `healthy` state.
- `wp core is-installed` passed and `wp plugin is-active wp-site-options` passed.
- WordPress `home` and `siteurl` both equalled `http://wp-site-options.local:49188`.
- `curl --resolve wp-site-options.local:49188:127.0.0.1 http://wp-site-options.local:49188/` returned HTTP `200`; `/wp-admin/` returned the expected `302` login redirect on the same host and port.
- The plugin link resolved exactly to `/srv/web/plugin-dir`; the fixture link resolved exactly to `/srv/web/tests/fixtures/wp-site-options-fixture.php`.
- Docker inspection showed the repository bind mounted at `/srv/web`. Inside `wp-cli`, the installed entrypoint and `/srv/web/plugin-dir/wp-site-options.php` were the same file (`test -ef`) and had the same SHA-256. This verifies that the symlink uses the live repository bind mount without copying source files.
- The fixture registered representative `headline:text`, `featured:checkbox`, and `items_per_page:number` fields.

### Idempotency and persistence

- A marker option with value `e2-qa-preserve-1740` was created before the repeat checks.
- A second `make setup` reused all three container IDs, reported the existing WordPress installation, retained the marker, plugin activation, fixture fields, and exact plugin symlink.
- `make down` removed the QA containers/network but retained `wsoqa-e2-20260908-1740_db-data` and `local-dev/`.
- `make up` recreated healthy services; WordPress remained installed, the plugin remained active, and the marker value was unchanged.

### Reset boundary and cleanup

- Non-interactive `make reset` without confirmation failed with exit code `2`, instructed the caller to use `--yes`, and left all three services and the marker intact.
- `./scripts/reset-local.sh --yes` removed the QA containers, QA network, QA database volume, and `local-dev/`, while preserving `.env` as documented.
- Post-reset label/name checks found no container, network, or volume belonging to `wsoqa-e2-20260908-1740`.
- The QA-created `.env` was then removed because it did not exist before the walkthrough.
- Pre-existing running containers retained their original IDs and remained running. Unrelated Docker work started concurrently during QA; it was neither addressed nor removed.

## Defects and residual risks

No E2 defects or regressions were found, and no risk acceptance is required.

The host OS hosts file was intentionally not modified. Hostname-based HTTP was verified with curl's explicit DNS override, while setup correctly emitted the documented hosts-file instruction. Native-Linux Docker and a Windows browser were documentation-reviewed rather than separately executed in this WSL2/Docker Desktop run.
