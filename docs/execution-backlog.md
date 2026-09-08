# Execution backlog: WP Site Options delivery

Статус документа: утверждённый план декомпозирован; реализация не начата.  
Источник: [delivery-plan.md](./delivery-plan.md)  
Дата: 2026-09-08

## Утверждённые ограничения

- Основная ветка: `master`.
- Первый автоматизированный release: `1.2.2`.
- Поддерживаемый минимум: ориентир WordPress 6.0+ и PHP 7.4+; точный верх матрицы фиксируется compatibility audit на дату реализации.
- Production-теги: `vX.Y.Z` и `v-X.Y.Z`; оба нормализуются в `X.Y.Z`.
- Prerelease-варианты обоих tag formats не публикуются в WordPress.org SVN.
- Локальный домен: `wp-site-options.local`.
- `plugin-dir/` — канонический source; local-dev WordPress подключает его симлинком.
- WordPress.org username: `vars.WPORG_USERNAME`; пароль: `secrets.WPORG_PASSWORD`.
- Первый цикл — maintenance-only: публичный API сохраняется, широкая модернизация исключена.

## Порядок и readiness

Начальная ready queue содержит только T1. После каждого коммита выполняется readiness sweep; зависимости переводятся из `waiting_dependency` в `todo` только после фактического завершения upstream-задач. E2 и E3 могут частично выполняться параллельно после E1. Каждый эпик завершается независимым QA до перехода его зависимых задач в `todo`.

## E1. Канонический Git snapshot и контракт совместимости

### T1. Импортировать чистый SVN snapshot

Status: completed  
Goal: Поместить актуальные production sources и WordPress.org assets в каноническую Git-структуру без SVN metadata и локальных артефактов.  
Scope:

- импорт `/mnt/d/WP/wp-site-options/trunk/` в `plugin-dir/`;
- импорт `/mnt/d/WP/wp-site-options/assets/` в `.wordpress-org/`;
- базовые `.gitignore`, `README.md` и структура `master`;
- включение утверждённых `docs/delivery-plan.md` и `docs/execution-backlog.md` в initial commit;
- побайтовое сравнение импортированных файлов с источником.

Out of Scope:

- изменение PHP/readme metadata;
- импорт `tags/` и полной SVN-истории;
- Docker, тесты и release workflows.

DoR:

- delivery plan и D1-D6 утверждены;
- SVN working copy имеет чистый status и известный URL/revision.

DoD:

- snapshot импортирован и закоммичен в `master`;
- `.svn`, дампы, логи, secrets и Windows-local files не отслеживаются;
- сравнение source/assets не показывает необъяснённых расхождений.

AC:

- Given чистый SVN `trunk`, when сравниваются его файлы с `plugin-dir/`, then содержимое совпадает побайтно.
- Given SVN `assets`, when сравниваются они с `.wordpress-org/`, then production assets совпадают.
- Given Git index, when выполняется поиск SVN metadata, then `.svn` отсутствует.

Dependencies:

- Нет upstream-задач.

Notes/Risks:

- Не переносить `.svn/wc.db` и исторические `tags`.
- Любое расхождение источника до копирования останавливает импорт и требует повторной фиксации revision.

Verification:

- `svn status /mnt/d/WP/wp-site-options`
- `diff -ru --exclude=.svn /mnt/d/WP/wp-site-options/trunk plugin-dir`
- `diff -ru --exclude=.svn /mnt/d/WP/wp-site-options/assets .wordpress-org`
- `git status --short` и inspection staged diff перед commit.

### T2. Зафиксировать provenance и публичные контракты

Status: completed  
Goal: Сделать происхождение snapshot и compatibility boundary проверяемыми до любых remediation changes.  
Scope:

- документ с SVN URL, working-copy revision, last changed revision и checksums;
- inventory глобального `$wpto`, `wpto\Theme_options`, `getOption()`, `$wpto->fields`, option keys, actions и filters;
- diff-summary между SVN tag `1.2` и imported trunk `1.2.1`.

Out of Scope:

- автоматические тесты контрактов;
- исправление обнаруженных проблем;
- продуктовая документация новых функций.

DoR:

- T1 completed, imported commit immutable и доступен для checksum.

DoD:

- provenance и compatibility inventory сохранены в `docs/` и закоммичены;
- каждый релевантный public contract связан с конкретным source path/symbol;
- untagged `1.2.1` state описан без предположений.

AC:

- Given imported commit, when проверяются recorded checksums, then они воспроизводятся.
- Given compatibility inventory, when выбирается public hook или option key, then указан его source и ожидаемое legacy behavior.
- Given последняя tagged версия, when читается diff summary, then gallery behavior и metadata changes trunk перечислены.

Dependencies:

- T1.

Notes/Risks:

- Inventory является regression boundary, а не обещанием сохранить внутренние implementation details.

Verification:

- checksum regeneration;
- `rg` по declared symbols/hooks;
- review diff `tags/1.2` → imported `plugin-dir/`.

### T3. Нормализовать metadata для версии 1.2.2

Status: waiting_dependency  
Goal: Подготовить согласованный version contract будущего первого автоматизированного релиза.  
Scope:

- plugin header version `1.2.2`;
- `Stable tag: 1.2.2`;
- release changelog entry, которую последующие remediation/release tasks дополняют только фактически выполненными changes;
- утверждённые minimum requirements WordPress 6.0+/PHP 7.4+;
- `Tested up to` не повышается выше уже указанного `6.8` до появления evidence из E3;
- сохранение slug, text domain и публичных идентификаторов.

Out of Scope:

- создание Git tag или SVN tag;
- функциональные изменения;
- необоснованное увеличение `Tested up to` до непроверенной версии.

DoR:

- T2 completed и утверждённая minimum support policy зафиксирована.

DoD:

- все version sources согласованы на `1.2.2`;
- minimum metadata отражает утверждённую policy, а `Tested up to` не содержит нового неподтверждённого значения;
- изменение закоммичено с понятным changelog.

AC:

- Given plugin entrypoint/readme/changelog, when version validator их читает, then результат равен `1.2.2`.
- Given initial metadata normalization, when `Tested up to` сравнивается с исходным snapshot, then значение не повышено без test evidence.
- Given public identifiers, when сравниваются до/после, then они не изменены.

Dependencies:

- T2.

Notes/Risks:

- После E3 значение `Tested up to` может быть повышено отдельным проверенным change до актуальной протестированной версии.

Verification:

- version extraction script;
- metadata diff review;
- comparison с imported snapshot, подтверждающий отсутствие неподтверждённого повышения `Tested up to`.

### T4. Провести независимый QA эпика E1

Status: waiting_dependency  
Goal: Независимо подтвердить точность импорта, provenance и отсутствие непреднамеренного изменения публичного контракта.  
Scope:

- проверка AC/DoD T1-T3;
- повторное source/assets comparison;
- review provenance, metadata и Git history;
- итог `pass`, `pass_with_notes` или `fail`.

Out of Scope:

- реализация исправлений;
- оценка будущих Docker/CI решений.

DoR:

- T1-T3 completed и закоммичены.

DoD:

- QA evidence сохранён;
- все E1 success criteria проверены независимо;
- defects превращены в отдельные backlog tasks при `fail`.

AC:

- Given E1 deliverables, when QA повторяет проверки, then нет необъяснённых source/assets differences.
- Given Git history, when QA инспектирует commits, then нет SVN metadata, secrets или unrelated files.

Dependencies:

- T1, T2, T3.

Notes/Risks:

- QA owner не должен быть автором implementation tasks E1.

Verification:

- независимый rerun команд T1-T3 и review staged/committed artifacts.

## E2. Воспроизводимое локальное Docker-окружение

### T5. Создать базовый Docker Compose stack

Status: waiting_dependency  
Goal: Поднять изолированные `db`, `wordpress` и `wp-cli` с configurable PHP image/project/ports и безопасным хранением данных.  
Scope:

- `docker-compose.yml`, `.env.example` и минимальные Docker configs;
- named database volume;
- health checks и service dependencies;
- единый root mount, необходимый для local-dev symlink;
- defaults для `wp-site-options.local`.

Out of Scope:

- создание симлинка и WordPress bootstrap;
- production hosting/HTTPS;
- Node service.

DoR:

- T4 completed с QA result `pass`;
- support-matrix images определены хотя бы для default local profile.

DoD:

- stack стартует и завершается без ручного редактирования tracked files;
- credentials находятся только в ignored `.env`;
- database state переживает обычный `down` и удаляется только explicit reset.

AC:

- Given `.env.example`, when создаётся `.env` и запускается stack, then health checks становятся healthy.
- Given повторный `up`, when stack уже создан, then операция идемпотентна.
- Given обычный `down/up`, when WordPress снова доступен, then database state сохранён.

Dependencies:

- T4.

Notes/Risks:

- Container/volume/port names должны быть project-scoped и не конфликтовать с другими WordPress stacks.

Verification:

- `docker compose config`
- `docker compose up -d`
- `docker compose ps`
- persistence smoke после `down/up`.

### T6. Реализовать local-dev bootstrap, домен и симлинк

Status: waiting_dependency  
Goal: Автоматически установить WordPress на `wp-site-options.local` и подключить канонический `plugin-dir/` через симлинк.  
Scope:

- idempotent setup scripts;
- local-dev WordPress layout;
- симлинк `local-dev/wp-content/plugins/wp-site-options` → `/srv/web/plugin-dir`;
- core install, plugin activation и representative fixture fields;
- понятная hosts-file инструкция/проверка.

Out of Scope:

- копирование plugin source в local-dev;
- изменение host hosts-file без участия пользователя;
- destructive database reset по умолчанию.

DoR:

- T5 completed;
- canonical container path `/srv/web/plugin-dir` подтверждён compose config.

DoD:

- setup идемпотентно создаёт корректный симлинк;
- WordPress отвечает на `wp-site-options.local`;
- плагин активен, а fixture регистрирует representative fields;
- reset отделён и требует явной команды.

AC:

- Given clean local stack, when выполняется setup, then symlink target равен `/srv/web/plugin-dir`.
- Given edit в host `plugin-dir/`, when файл читается в WordPress container, then изменение видно без sync/copy.
- Given второй setup, when installation уже существует, then данные и корректный symlink сохраняются.

Dependencies:

- T5.

Notes/Risks:

- Symlink создаётся внутри общего container mount; host Windows junction не требуется.

Verification:

- `readlink` внутри WordPress/PHP container;
- `wp core is-installed`;
- `wp plugin is-active wp-site-options`;
- HTTP smoke по `wp-site-options.local`.

### T7. Добавить Make-команды и development guide

Status: waiting_dependency  
Goal: Дать разработчику стабильный command interface для setup, работы, тестов, логов и безопасного reset.  
Scope:

- Make targets `setup`, `up`, `down`, `reset`, `logs`, `shell`, `test`, `lint`, `release-zip`;
- `docs/development.md` для WSL2/Docker Desktop/Linux;
- troubleshooting домена, ports, permissions и symlink.

Out of Scope:

- release runbook;
- CI implementation;
- автоматическое изменение системных DNS/hosts.

DoR:

- T6 completed и команды underlying scripts стабильны.

DoD:

- все targets документированы и используют Compose project scope;
- destructive target явно назван и подтверждает scope;
- clean-machine walkthrough воспроизводим.

AC:

- Given development guide, when новый пользователь выполняет setup path, then получает активный плагин на локальном домене.
- Given `make reset`, when команда запускается, then она затрагивает только project-scoped local-dev data.

Dependencies:

- T6.

Notes/Risks:

- Не скрывать destructive behavior за общими названиями вроде `clean`.

Verification:

- dry-run/review Make targets;
- documented setup walkthrough;
- scope inspection перед reset test.

### T8. Провести независимый QA эпика E2

Status: waiting_dependency  
Goal: Независимо подтвердить clean setup, идемпотентность, домен и корректность local-dev symlink.  
Scope:

- AC/DoD T5-T7;
- clean and repeat setup;
- persistence/reset boundaries;
- WSL-oriented documentation review.

Out of Scope:

- CI и release pipeline.

DoR:

- T5-T7 completed.

DoD:

- QA report сохранён;
- E2 имеет `pass` либо defects оформлены задачами.

AC:

- Given clean Docker state scoped to project, when QA следует docs, then WordPress открывается на `wp-site-options.local` и source подключён симлинком.
- Given repeat setup, when QA сравнивает state, then нет дублирования/потери данных.

Dependencies:

- T5, T6, T7.

Notes/Risks:

- QA не должен удалять unrelated Docker volumes/containers.

Verification:

- independent development guide walkthrough и recorded evidence.

## E3. Автоматизированные тесты и CI quality gates

### T9. Создать Composer test/tooling harness

Status: waiting_dependency  
Goal: Зафиксировать воспроизводимые dev dependencies и команды PHP lint/unit/integration/coding checks.  
Scope:

- root `composer.json`/lock для test tooling;
- PHPUnit/WordPress test bootstrap;
- scripts для lint, test suites и локального WordPress Plugin Check preflight;
- separation dev tooling от production `plugin-dir/`.

Out of Scope:

- runtime Composer dependencies;
- test cases публичного поведения;
- CI workflow.

DoR:

- T4 completed с QA result `pass`;
- support minimum PHP 7.4 утверждён.

DoD:

- `composer install` и empty/smoke suite работают на clean environment;
- lockfile закоммичен;
- production ZIP source не зависит от dev vendor.

AC:

- Given clean checkout, when выполняется Composer install, then tooling versions детерминированы lockfile.
- Given PHP minimum, when test bootstrap запускается, then syntax/dependencies совместимы.

Dependencies:

- T4.

Notes/Risks:

- Версии PHPUnit/WP test tools должны одновременно поддерживать minimum и актуальный PHP profiles.

Verification:

- `composer validate --strict`
- `composer install --no-interaction`
- Composer script smoke.

### T10. Добавить characterization tests публичного API

Status: waiting_dependency  
Goal: Защитить legacy public contracts до compatibility remediation.  
Scope:

- global `$wpto` initialization;
- settings/option names;
- `getOption()` raw, filtered, default и gallery behavior;
- hook names/accepted args;
- representative field registration/rendering и custom-field filter;
- empty/partial option edge cases как зафиксированное ожидаемое поведение или defect characterization.

Out of Scope:

- browser workflow;
- изменение production code без отдельной remediation task;
- 100% coverage.

DoR:

- T2 и T9 completed.

DoD:

- inventory T2 трассируется к тестам;
- tests падают при намеренном нарушении ключевых contracts;
- неоднозначные edge cases помечены как defects/legacy behavior.

AC:

- Given legacy option data, when public API читает значение, then raw/default/gallery результаты соответствуют inventory.
- Given registered filters, when API вызывается, then имена и количество аргументов совместимы.

Dependencies:

- T2, T9.

Notes/Risks:

- Не закреплять случайные implementation details, которые не являются публичным контрактом.

Verification:

- Composer characterization test command;
- mutation check одного ключевого assertion с последующим revert.

### T11. Добавить WordPress integration tests

Status: waiting_dependency  
Goal: Проверить plugin lifecycle, settings registration и persistence в реальном WordPress.  
Scope:

- чистая activation;
- fixture fields на Settings → Reading;
- option save/read round trip;
- minimum/latest WordPress/PHP profiles;
- installation/activation собранного кандидата, когда builder станет доступен.

Out of Scope:

- pixel-perfect browser UI;
- release publication.

DoR:

- T6, T9 и T10 completed.

DoD:

- integration suite выполняется локально и в clean container;
- minimum/latest profiles дают evidence;
- failures сохраняют диагностические logs.

AC:

- Given clean WordPress, when plugin активируется, then fatal errors отсутствуют.
- Given fixture fields and saved values, when public API читает options, then значения и типы ожидаемы.

Dependencies:

- T6, T9, T10.

Notes/Risks:

- Matrix может выявить несовместимость, которая переводит T13 в runnable remediation.

Verification:

- integration commands для minimum/latest profiles;
- WordPress debug log inspection.

### T12. Добавить authenticated admin smoke

Status: waiting_dependency  
Goal: Проверить критический пользовательский сценарий Settings → Reading в браузере.  
Scope:

- login admin;
- видимость representative fields;
- изменение и сохранение значений;
- отсутствие console/PHP errors;
- screenshot/trace только при сбое.

Out of Scope:

- широкая cross-browser matrix;
- визуальный редизайн;
- тестирование всех комбинаций attrs.

DoR:

- T11 completed и local-dev fixture стабилен.

DoD:

- deterministic smoke проходит локально/headless;
- failure evidence пригодно для диагностики;
- тест не зависит от внешней сети.

AC:

- Given authenticated admin, when открывается Reading Settings, then fixture fields доступны.
- Given changed values, when settings сохраняются и страница перезагружается, then значения сохраняются.

Dependencies:

- T11.

Notes/Risks:

- Playwright добавляется только как test dependency, без Node runtime в plugin release.

Verification:

- headless admin smoke command;
- artifacts on intentional failure.

### T13. Исправить release-blocking compatibility/security findings

Status: waiting_dependency  
Goal: Устранить только доказанные блокеры утверждённой матрицы и Plugin Check без изменения публичного API.  
Scope:

- PHP warnings/fatals в поддерживаемой матрице;
- sanitization/escaping/nonce/capability findings, признанные blocking;
- финальное подтверждённое `Tested up to` и фактическое дополнение changelog;
- regression tests на каждое исправление;
- минимальный production diff.

Out of Scope:

- широкая OO-архитектурная переработка;
- style-only modernization;
- новые функции.

DoR:

- T10-T12 дали воспроизводимые findings;
- Plugin Check report классифицирован;
- исправление не требует изменения утверждённого public contract; иначе нужен новый human decision gate.

DoD:

- blocking findings устранены;
- regression tests проходят minimum/latest profiles;
- residual warnings документированы и не маскируются.

AC:

- Given исходный failing case, when применяется fix, then test проходит без public API regression.
- Given Plugin Check, when анализ повторяется, then blocking finding отсутствует.

Dependencies:

- T10, T11, T12;
- initial Plugin Check evidence.

Notes/Risks:

- Scope задачи уточняется по фактическим findings; API-breaking fix останавливает execution на human gate.

Verification:

- targeted regression tests;
- full test matrix;
- Plugin Check rerun;
- production diff review.

### T14. Реализовать CI workflow для master и pull requests

Status: waiting_dependency  
Goal: Сделать обязательные quality gates автоматическими и воспроизводимыми на GitHub Actions.  
Scope:

- `.github/workflows/ci.yml` для PR и push в `master`;
- PHP lint, tests, Plugin Check и позднее release ZIP gate;
- dependency caches;
- least-privilege permissions, concurrency и failure artifacts;
- draft PR policy.

Out of Scope:

- tag release и SVN deploy;
- автоматический push/commit из CI.

DoR:

- T9-T13 completed либо T13 подтверждён как no-op после чистых reports;
- команды локальной проверки стабильны.

DoD:

- workflow проходит на clean runner;
- intentional test failure блокирует job;
- CI не читает release credentials;
- required check names задокументированы.

AC:

- Given PR в `master`, when обязательный тест падает, then workflow имеет failure conclusion.
- Given passing commit, when workflow завершается, then все gates зелёные и diagnostics доступны.

Dependencies:

- T9, T10, T11, T12, T13.

Notes/Risks:

- Release ZIP steps подключаются после E4 без дублирования test logic.

Verification:

- workflow syntax review;
- local commands parity;
- GitHub Actions run на test branch/PR.

### T15. Провести независимый QA эпика E3

Status: waiting_dependency  
Goal: Проверить, что tests и CI доказывают contracts, а не только подтверждают текущую реализацию.  
Scope:

- AC/DoD T9-T14;
- независимый test/matrix/Plugin Check run;
- controlled negative test CI gate;
- remediation/public API review.

Out of Scope:

- release artifact/deploy.

DoR:

- T9-T14 completed.

DoD:

- QA outcome и evidence сохранены;
- E3 success criteria verified;
- gaps оформлены задачами.

AC:

- Given deliberate contract break, when suite запускается, then relevant test fails.
- Given clean source, when full CI equivalent выполняется, then blocking findings отсутствуют.

Dependencies:

- T9-T14.

Notes/Risks:

- QA owner независим от implementers E3.

Verification:

- independent rerun full CI-equivalent command set.

## E4. Детерминированный release artifact

### T16. Реализовать build и strict ZIP validator

Status: waiting_dependency  
Goal: Собирать installable ZIP из `plugin-dir/` и отвергать unsafe/несогласованный артефакт.  
Scope:

- `scripts/build-release-zip.sh`;
- `scripts/validate-release-zip.sh`;
- один root `wp-site-options/`;
- exclusions для dev/tests/docs/assets/secrets;
- version/readme/changelog consistency;
- normalized timestamps/order.

Out of Scope:

- GitHub Release и SVN deployment;
- Composer runtime vendor.

DoR:

- T15 completed с QA result `pass`;
- T3 version policy completed;
- production file set известен.

DoD:

- ZIP проходит `unzip -t` и strict validator;
- forbidden artifacts отсутствуют;
- validator принимает expected version в нормализованном виде.

AC:

- Given clean source, when builder запускается, then создаётся installable `wp-site-options` ZIP.
- Given forbidden file или version mismatch, when validator запускается, then он завершается non-zero до публикации.

Dependencies:

- T3, T15.

Notes/Risks:

- Allowlist assertions защищают от ошибочного удаления production files overly broad excludes.

Verification:

- build command;
- `unzip -Z1` inspection;
- strict validator с expected version.

### T17. Добавить negative и reproducibility tests

Status: waiting_dependency  
Goal: Доказать ZIP hygiene и byte-for-byte reproducibility.  
Scope:

- fixtures forbidden files/outside-root/version mismatch;
- двойная сборка одного commit;
- SHA-256/cmp evidence;
- install/activation smoke candidate ZIP.

Out of Scope:

- публикация артефакта;
- SVN fixture.

DoR:

- T16 completed;
- T11 integration install path доступен.

DoD:

- все negative fixtures ожидаемо отвергаются;
- две clean builds совпадают;
- candidate устанавливается и активируется.

AC:

- Given same commit and source epoch, when выполняются две builds, then SHA-256 идентичен.
- Given `.env`, `.svn`, test или external-root entry, when ZIP валидируется, then validator fails.

Dependencies:

- T11, T16.

Notes/Risks:

- ZIP timestamps зависят от timezone; build явно фиксирует UTC/source epoch.

Verification:

- negative test script;
- two-build `cmp` and `sha256sum`;
- ZIP install smoke.

### T18. Подключить verified ZIP artifact к CI

Status: waiting_dependency  
Goal: Создавать в CI ровно тот кандидат, который впоследствии используется release workflow.  
Scope:

- build/validate/reproducibility steps в CI;
- upload immutable candidate artifact;
- retention/name conventions;
- checksums в job summary/artifacts.

Out of Scope:

- публикация GitHub Release;
- SVN credentials/deploy.

DoR:

- T14 и T17 completed.

DoD:

- passing CI содержит verified ZIP и checksum;
- failed validation не загружает publishable artifact;
- release workflow может адресовать artifact однозначно.

AC:

- Given passing `master`/PR workflow, when job завершается, then artifact проходит повторный validator после download.
- Given build failure, when workflow завершается, then publish job отсутствует.

Dependencies:

- T14, T17.

Notes/Risks:

- PR artifacts никогда не публикуются автоматически.

Verification:

- GitHub Actions artifact download and revalidation.

### T19. Провести независимый QA эпика E4

Status: waiting_dependency  
Goal: Независимо проверить installability, hygiene и reproducibility release artifact.  
Scope:

- AC/DoD T16-T18;
- manual ZIP listing inspection;
- repeat build/download/revalidate;
- install smoke.

Out of Scope:

- SVN deployment.

DoR:

- T16-T18 completed.

DoD:

- QA outcome/evidence сохранены;
- artifact признан пригодным как единственный release candidate.

AC:

- Given CI candidate, when QA downloads and validates it, then checksum/content совпадают с build evidence.
- Given installed candidate, when plugin активируется, then smoke passes.

Dependencies:

- T16-T18.

Notes/Risks:

- QA проверяет artifact, не рабочую директорию.

Verification:

- independent build, validate, checksum и install commands.

## E5. Tag-driven GitHub и WordPress.org release

### T20. Реализовать безопасный WordPress.org SVN deploy script

Status: waiting_dependency  
Goal: Синхронизировать один verified unpacked ZIP в SVN `trunk/assets/tags` с идемпотентностью и защитой существующих tags.  
Scope:

- checkout/update managed paths;
- exact sync artifact → `trunk`, `.wordpress-org` → `assets`;
- SVN add/remove/mime properties;
- `svn cp trunk tags/<version>`;
- XML status validation;
- dry-run и identical-existing-tag no-op.

Out of Scope:

- GitHub workflow;
- secrets storage;
- перезапись differing existing tag.

DoR:

- T19 completed;
- verified artifact contract стабилен.

DoD:

- script работает с explicit slug/version/build path;
- unsafe/conflicted status hard-fails;
- credentials требуются только для non-dry-run commit;
- cleanup ограничен temporary/project-scoped path.

AC:

- Given clean candidate, when dry-run выполняется, then status содержит точные trunk/assets/tag changes без commit.
- Given identical existing tag, when deploy повторяется, then result no-op.
- Given differing existing tag, when deploy повторяется, then script fails до commit.

Dependencies:

- T19.

Notes/Risks:

- Удаления строятся из snapshot SVN status, чтобы избежать race при rsync/removal.

Verification:

- shell/Python lint;
- local fixture SVN scenarios;
- dry-run status inspection.

### T21. Добавить fixture tests SVN deploy

Status: waiting_dependency  
Goal: Автоматически доказать корректность happy path, rerun и unsafe-state safeguards без доступа к WordPress.org.  
Scope:

- temporary local SVN repository;
- first deploy, identical rerun, conflicting tag, deleted files/assets, unsafe status;
- assertion exact trunk/tag/assets tree.

Out of Scope:

- реальный WordPress.org commit;
- GitHub credentials.

DoR:

- T20 completed.

DoD:

- fixture tests воспроизводимы локально/CI;
- destructive tests ограничены validated temp directory;
- expected failure cases проверяют non-zero и отсутствие commit.

AC:

- Given empty fixture repo, when candidate deploys, then trunk/tag/assets exact-match expected trees.
- Given unsafe/differing state, when deploy запускается, then repository revision не меняется.

Dependencies:

- T20.

Notes/Risks:

- Temp paths создаются через `mktemp`; broad cleanup запрещён.

Verification:

- fixture test script;
- SVN log/tree assertions after every scenario.

### T22. Реализовать release workflow и нормализацию tags

Status: waiting_dependency  
Goal: Автоматически создавать GitHub Release и запускать production SVN deploy для обоих утверждённых tag formats.  
Scope:

- `.github/workflows/release.yml`;
- triggers для `vX.Y.Z`, `v-X.Y.Z` и prerelease variants;
- parser/validator optional hyphen;
- tag/header/stable/changelog equality;
- GitHub Release + verified ZIP/checksum;
- prerelease no-SVN rule;
- production SVN job, concurrency и least privilege.

Out of Scope:

- branch-push deployment;
- manual modification SVN working copy;
- stable mirror branch.

DoR:

- T18, T21 completed;
- D3/D6 утверждены.

DoD:

- оба production formats дают version `X.Y.Z`;
- malformed/mismatched tags fail до publication;
- prerelease публикует только GitHub prerelease;
- production использует `vars.WPORG_USERNAME` и `secrets.WPORG_PASSWORD` только в deploy job.

AC:

- Given `v1.2.2` or `v-1.2.2`, when parser runs, then normalized version is `1.2.2` for both.
- Given either valid production format and matching metadata, when gates pass, then GitHub Release is created and SVN job becomes eligible.
- Given prerelease or mismatch, when workflow runs, then WordPress.org SVN commit does not occur.

Dependencies:

- T18, T21.

Notes/Risks:

- GitHub glob patterns are insufficient for semantic validation; shell/parser gate remains authoritative.

Verification:

- parser table tests for valid/invalid tags;
- workflow syntax/actionlint if available;
- test tag in non-production fixture path.

### T23. Проверить Actions configuration и выполнить real SVN dry-run

Status: waiting_dependency  
Goal: Подтвердить availability правильных GitHub contexts и реальный WordPress.org delta без commit.  
Scope:

- наличие `vars.WPORG_USERNAME` без раскрытия значения;
- наличие `secrets.WPORG_PASSWORD` без чтения/логирования;
- GitHub Environment/permissions review;
- dry-run against fresh real WordPress.org checkout;
- сохранение sanitized status evidence.

Out of Scope:

- production SVN commit;
- вывод credential values;
- создание production tag.

DoR:

- T22 completed;
- owner configuration доступна workflow;
- E1-E4 QA passed.

DoD:

- variable/secret references resolution подтверждено безопасным preflight;
- real dry-run показывает только ожидаемые trunk/assets/tag changes;
- неожиданные removals/additions отсутствуют или оформлены blocker task.

AC:

- Given workflow environment, when preflight runs, then username/password contexts определены без вывода values.
- Given verified 1.2.2 candidate, when real dry-run запускается, then SVN commit count не меняется.

Dependencies:

- T22;
- repository/environment variable `WPORG_USERNAME`;
- repository/environment secret `WPORG_PASSWORD`.

Notes/Risks:

- Если password secret ещё не создан, задача остаётся `waiting_dependency`; это не блокирует локальные fixture tests.

Verification:

- safe GitHub Actions preflight;
- before/after SVN revision;
- sanitized `svn status` evidence.

### T24. Провести независимый QA эпика E5

Status: waiting_dependency  
Goal: Независимо проверить tag parsing, publish boundaries, idempotency и real dry-run evidence.  
Scope:

- AC/DoD T20-T23;
- valid/invalid/prerelease tag table;
- fixture rerun/conflict tests;
- permissions/context review;
- real dry-run evidence.

Out of Scope:

- production tag/commit.

DoR:

- T20-T23 completed.

DoD:

- QA outcome сохранён;
- E5 готов к controlled production release либо defects оформлены задачами.

AC:

- Given both approved production tag formats, when QA repeats normalization, then outputs equal.
- Given prerelease, when workflow paths inspect, then SVN job cannot commit.
- Given real dry-run, when evidence review completes, then no unexplained delta remains.

Dependencies:

- T20-T23.

Notes/Risks:

- QA owner не использует credential values и не запускает non-dry-run deploy.

Verification:

- independent rerun of parser/fixture tests and dry-run evidence review.

## E6. Cutover, первая публикация и runbook

### T25. Оформить release/recovery runbook и protections

Status: waiting_dependency  
Goal: Сделать `master` и tag-driven production процесс управляемыми до первого реального deploy.  
Scope:

- `docs/release.md` и recovery/rerun steps;
- required checks и protections для `master`;
- tag naming examples обоих formats;
- version/changelog checklist;
- GitHub Variables/Secrets/Environment checklist;
- post-release verification и rollback limitations.

Out of Scope:

- создание production tag;
- SVN commit;
- удаление Windows SVN working copy.

DoR:

- T24 completed;
- окончательные workflow/check names известны.

DoD:

- runbook проходит dry walkthrough;
- protections соответствуют CI names;
- recovery не предлагает перезапись SVN tag;
- Windows SVN copy обозначена read-only/reference после cutover.

AC:

- Given maintainer following runbook, when он готовит release, then оба допустимых tag formats и последствия ясно описаны.
- Given partial GitHub/SVN failure, when применяется rerun path, then используется тот же immutable candidate.

Dependencies:

- T24.

Notes/Risks:

- Git tag считается production intent; удаление remote tag не является rollback опубликованного SVN release.

Verification:

- tabletop release/recovery walkthrough;
- GitHub settings review.

### T26. Выпустить первую автоматизированную версию 1.2.2

Status: waiting_dependency  
Goal: Провести controlled end-to-end GitHub и WordPress.org publication из проверенного commit.  
Scope:

- final version/support/changelog check;
- production tag одного из утверждённых formats;
- monitoring CI, GitHub Release и SVN deploy;
- сохранение artifact/checksum/run links.

Out of Scope:

- изменение кода после tag;
- принятие unresolved QA risk без владельца;
- перезапись release/tag.

DoR:

- T25 completed;
- E1-E5 QA result `pass`;
- explicit human approval первого production release;
- required variable/secret/environment доступны.

DoD:

- GitHub Release `1.2.2` содержит verified ZIP/checksum;
- WordPress.org trunk/assets/tag `1.2.2` соответствуют артефакту;
- workflow завершён success без credential leakage.

AC:

- Given approved `1.2.2` tag, when workflow completes, then GitHub Release and SVN tag exist and derive from same checksum-identified artifact.
- Given deploy logs, when они инспектируются, then secret values отсутствуют.

Dependencies:

- T25;
- explicit human production approval.

Notes/Risks:

- Реальный SVN commit необратим обычным Git rollback; при дефекте потребуется новая patch version.

Verification:

- GitHub Release asset checksum;
- fresh SVN checkout comparison;
- workflow/log inspection.

### T27. Провести post-release QA и закрыть cutover

Status: waiting_dependency  
Goal: Подтвердить, что опубликованный релиз устанавливается/обновляется и GitHub стал каноническим delivery source.  
Scope:

- fresh install from WordPress.org/GitHub ZIP;
- update/activation/settings smoke;
- public API representative checks;
- WordPress.org page/version propagation;
- closure evidence и остаточные риски.

Out of Scope:

- новые fixes внутри `1.2.2`;
- удаление исторической SVN data.

DoR:

- T26 completed и WordPress.org propagation доступна.

DoD:

- post-release QA имеет `pass` либо defect создаёт новую patch-release task;
- published trees/checksums согласованы;
- Windows SVN working copy больше не используется для новых правок;
- delivery closure report сохранён.

AC:

- Given fresh WordPress, when published plugin installs/activates, then critical settings scenario passes без PHP errors.
- Given SVN/GitHub artifacts, when trees сравниваются, then installable content идентично.
- Given next planned change, when source location проверяется, then работа начинается из Git `master`/feature branch.

Dependencies:

- T26;
- WordPress.org propagation.

Notes/Risks:

- Product-visible или operationally meaningful `pass_with_notes` требует human risk acceptance.

Verification:

- independent fresh install/update smoke;
- fresh SVN checkout vs GitHub ZIP comparison;
- final QA/closure report.

## Рекомендуемый первый execution batch

**Batch 1: T1 — импорт чистого SVN snapshot.** Это единственная задача со статусом `todo`; её выполнение создаёт durable canonical source commit и разблокирует T2. После завершения T1 delivery owner выполняет readiness sweep и, в рамках утверждённой execution strategy, продолжает E1 до независимого QA. Только после QA result `pass` параллельно разблокируются T5 и T9.

Write scope Batch 1:

- `plugin-dir/**`;
- `.wordpress-org/**`;
- `.gitignore`;
- `README.md`;
- `docs/delivery-plan.md` и `docs/execution-backlog.md` только для фиксации утверждённых planning artifacts и обновления статуса T1;
- при необходимости provenance-заготовка в `docs/`.

Обязательная проверка Batch 1:

- clean SVN status;
- exact source/assets diff;
- secret/local-artifact inspection;
- staged diff review;
- scoped commit в `master`;
- readiness sweep T2.

Для начала Batch 1 требуется отдельное одобрение владельца.
