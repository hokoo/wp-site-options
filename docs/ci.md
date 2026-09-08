# Continuous integration

The `CI` workflow runs for pushes to `master` and pull requests targeting `master`. Pull-request activity is limited to `opened`, `synchronize`, `reopened`, `ready_for_review`, and `converted_to_draft`.

Draft pull requests intentionally skip every quality job. A PR moving back to ready-for-review triggers the complete suite. Concurrency is scoped to the workflow and PR number; a newer run cancels an older run for the same PR. Push runs use their Git ref and are not cancelled automatically.

The workflow has one top-level permission, `contents: read`. It does not receive, reference, or publish release credentials and never commits or pushes repository changes.

## Stable required-check names

Configure branch protection for `master` with these exact checks:

- `PHP quality / PHP 7.4`
- `PHP quality / PHP 8.3`
- `WordPress integration / minimum`
- `WordPress integration / latest`
- `Plugin Check`
- `Authenticated admin smoke`

Matrix values and explicit job names are part of this contract. Renaming one requires updating branch protection at the same time.

## Gates

| Check | Commands and guarantees |
| --- | --- |
| PHP quality / PHP 7.4 | Composer validation/install/audit, PHP lint, and unit tests on the minimum PHP runtime. |
| PHP quality / PHP 8.3 | The same Composer and test path on the current supported local PHP profile. |
| WordPress integration / minimum | `scripts/test-integration.sh minimum`: WordPress 6.0 and PHP 7.4 lifecycle/persistence checks. |
| WordPress integration / latest | `scripts/test-integration.sh latest`: current WordPress and PHP 8.3 lifecycle/persistence checks. |
| Plugin Check | `scripts/plugin-check.sh`: pinned Plugin Check strict JSON with a zero-ERROR requirement. |
| Authenticated admin smoke | npm audit, isolated local Compose setup, and the Playwright login → Settings → Reading → save/reload path. |

The authenticated smoke keeps `wp-site-options.local` in the browser URL. Its Chromium host-resolver rule maps that name to `127.0.0.1`; CI does not mutate `/etc/hosts`. The Compose project name contains the GitHub run id and attempt, and an `always()` cleanup invokes the explicit project-scoped reset.

Release ZIP creation and validation are intentionally absent. They join CI only after the deterministic builder is delivered in T18.

## Dependency caching and action pinning

Composer archives are cached per operating system, PHP version, and `composer.lock`. `setup-node` manages the npm cache using `package-lock.json`. `vendor/`, `node_modules/`, WordPress files, databases, and browser binaries are not cached.

Actions are pinned to immutable commits resolved from the current official release tags on 2026-09-08:

| Action | Release | Commit |
| --- | --- | --- |
| [`actions/checkout`](https://github.com/actions/checkout/releases/tag/v7.0.1) | v7.0.1 | `3d3c42e5aac5ba805825da76410c181273ba90b1` |
| [`actions/setup-node`](https://github.com/actions/setup-node/releases/tag/v7.0.0) | v7.0.0 | `820762786026740c76f36085b0efc47a31fe5020` |
| [`actions/cache`](https://github.com/actions/cache/releases/tag/v6.1.0) | v6.1.0 | `55cc8345863c7cc4c66a329aec7e433d2d1c52a9` |
| [`actions/upload-artifact`](https://github.com/actions/upload-artifact/releases/tag/v7.0.1) | v7.0.1 | `043fb46d1a93c77aae656e7c1c64a875d1fc6a0a` |
| [`shivammathur/setup-php`](https://github.com/shivammathur/setup-php/releases/tag/2.37.2) | 2.37.2 | `f3e473d116dcccaddc5834248c87452386958240` |

Only GitHub-hosted `ubuntu-24.04` runners are assumed. New Action releases should be reviewed and resolved to a new full commit SHA rather than replacing pins with moving major tags.

## Failure diagnostics

Integration and Plugin Check failures upload their uniquely generated `tests/integration/artifacts/` content, including command output, Compose logs, WordPress debug output, lifecycle JSON, and Plugin Check JSON when available.

The browser job collects Compose state/logs before cleanup. Playwright stores screenshots and traces only for failures. The combined ignored `test-results/` directory is uploaded only when the job has failed. Artifact retention is seven days, and artifact names include the GitHub run id and attempt.

## Local parity

Run the same gates locally from a clean checkout:

```bash
composer validate --strict --no-interaction
composer install --no-interaction --prefer-dist --no-progress
composer audit --no-interaction
composer lint:php
composer test:unit

scripts/test-integration.sh minimum
scripts/test-integration.sh latest
scripts/plugin-check.sh

npm ci --no-audit --no-fund
npm audit --audit-level=high
npm run test:e2e:install
make setup
npm run test:e2e
./scripts/reset-local.sh --yes
```

The GitHub Actions run remains the final proof that event filters, draft policy, caches, permissions, artifacts, and hosted-runner behavior are valid.
