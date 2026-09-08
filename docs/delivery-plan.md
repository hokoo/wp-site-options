# План переноса и автоматизации WP Site Options

Статус: **утверждён; реализация ожидает одобрения первого execution batch**  
Дата: 2026-09-08  
Репозиторий назначения: `hokoo/wp-site-options`

План утверждён владельцем 2026-09-08. До отдельного одобрения первого execution batch не выполняются импорт исходников, изменение кода плагина, создание релизных веток/тегов, настройка GitHub Actions и публикация в WordPress.org SVN.

## 1. Исходное состояние

- GitHub-репозиторий создан, но пока не содержит веток и коммитов.
- Актуальный источник — чистая SVN working copy `/mnt/d/WP/wp-site-options` для `https://plugins.svn.wordpress.org/wp-site-options`.
- SVN working copy обновлена до ревизии `3283153`; последнее изменение самого плагина — ревизия `1608075` от 2017-03-05.
- Производственный код находится в `trunk`, WordPress.org-графика — в `assets`, исторические выпуски — в `tags`.
- В `trunk` указан plugin version `1.2.1`, но последний SVN-тег — `1.2`; тега `1.2.1` нет.
- В `trunk/readme.txt` указано `Stable tag: trunc`, что требует исправления перед автоматическим релизом.
- Код плагина небольшой, не имеет runtime-зависимостей Composer/Node и проходит синтаксическую проверку PHP 8.0. При этом его поведение на актуальных WordPress/PHP ещё не покрыто автоматическими тестами.
- Публичная совместимость завязана как минимум на глобальный объект `$wpto`, класс `wpto\Theme_options`, ключ опций `wpto_options`, формат описания `$wpto->fields`, метод `getOption()` и существующие actions/filters.

## 2. Цель

Сделать GitHub единственным источником разработки и релизов плагина, сохранив его публичное поведение, и получить воспроизводимый процесс:

1. локальная разработка и проверка в Docker;
2. автоматическая проверка каждого pull request и основной ветки;
3. детерминированная сборка installable ZIP;
4. публикация GitHub Release и WordPress.org SVN из одного проверенного артефакта при создании production-тега;
5. документированный, безопасный и повторяемый релизный процесс.

## 3. Пользователи результата

- разработчик плагина — локальная работа, тесты, выпуск версии;
- ревьюер — проверка PR и артефактов CI;
- пользователь WordPress — установка ZIP или обновление через WordPress.org без изменения существующего публичного API.

## 4. Критерии успеха

- Исходники из SVN `trunk` перенесены без `.svn` и без незафиксированных расхождений; происхождение snapshot задокументировано.
- WordPress.org assets хранятся отдельно от installable-кода и попадают только в SVN `assets`.
- Одна команда поднимает локальные WordPress и БД на `wp-site-options.local`, создаёт симлинк из local-dev WordPress plugins в `plugin-dir/`, активирует плагин и позволяет запустить тесты.
- CI блокирует слияние при ошибке PHP lint, обязательных тестов, WordPress Plugin Check, сборки или проверки ZIP.
- ZIP содержит ровно один корневой каталог `wp-site-options/`, не содержит dev-файлов/секретов и собирается байт-в-байт одинаково из одного коммита.
- Production-тег принимается только при совпадении версии тега, plugin header, `Stable tag` и changelog.
- Один и тот же проверенный ZIP прикрепляется к GitHub Release и разворачивается в WordPress.org SVN.
- SVN deployment обновляет `trunk`, `assets`, создаёт неизменяемый `tags/<version>` и безопасно повторяется после частичного сбоя.
- После dry-run и первого релиза подтверждены установка, активация, регистрация полей, сохранение/чтение опций и отсутствие PHP errors в поддерживаемой матрице.

## 5. Рекомендуемая архитектура репозитория

```text
wp-site-options/
├── .github/workflows/
│   ├── ci.yml
│   └── release.yml
├── .wordpress-org/          # banner, icon, screenshots для SVN assets
├── docs/
│   ├── delivery-plan.md
│   ├── development.md
│   └── release.md
├── docker/
│   └── ...                  # только нужные override/config файлы
├── plugin-dir/              # содержимое installable WordPress-плагина
│   ├── inc/
│   ├── languages/
│   ├── index.php
│   ├── readme.txt
│   └── wp-site-options.php
├── scripts/
│   ├── build-release-zip.sh
│   ├── validate-release-zip.sh
│   ├── deploy-wordpress-svn.sh
│   └── svn-status.py
├── tests/
│   ├── unit-or-characterization/
│   ├── integration/
│   └── e2e/
├── .env.example
├── .gitignore
├── composer.json
├── composer.lock
├── docker-compose.yml
├── Makefile
└── README.md
```

### Основные решения

- `plugin-dir/` — единственный источник installable-кода; SVN-layout `trunk/tags/assets` в Git не переносится.
- `.wordpress-org/` — источник только для WordPress.org assets и не входит в ZIP.
- Composer используется для dev/test-инструментов; runtime `vendor/` не добавляется без реальной зависимости плагина.
- Node не добавляется: у плагина нет frontend build pipeline. Playwright, если понадобится для admin smoke, запускается только как тестовый инструмент.
- Docker Compose включает `db`, `wordpress` и `wp-cli`. Корень репозитория монтируется в контейнер, а setup создаёт симлинк `local-dev/wp-content/plugins/wp-site-options` на канонический `/srv/web/plugin-dir`; release source при этом не дублируется. Локальный домен — `wp-site-options.local`. Порт, project name и PHP image tag задаются через `.env`, данные БД живут в именованном Docker volume.
- Основная ветка — `master`. Отдельная mirror-ветка с собранным плагином не создаётся: при отсутствии production build-зависимостей достаточно ZIP и WordPress.org SVN. Это уменьшает число источников истины.

## 6. Объём работ

### Входит в объём

- snapshot-импорт актуального SVN `trunk` и `assets`;
- первичная Git-структура, README, development/release документация;
- Docker-окружение и Make-команды;
- Composer dev tooling и тестовый каркас;
- characterization, integration и минимальный admin smoke набор тестов;
- статические и релизные quality gates;
- воспроизводимая ZIP-сборка и строгая проверка содержимого;
- GitHub Actions для CI и tag-driven release;
- безопасный скрипт WordPress.org SVN deploy и его dry-run/fixture tests;
- первый dry-run и первая контролируемая публикация.

### Не входит в объём

- перенос полной SVN-истории и преобразование старых SVN-тегов в Git-теги;
- редизайн UI или изменение модели объявления полей;
- переименование публичных PHP-symbols, hooks, option keys или text domain;
- добавление новых типов полей и продуктовых функций;
- широкая объектная переработка legacy-кода;
- изменение WordPress.org-описания и графики, кроме метаданных, необходимых для корректного релиза;
- автоматическое изменение локальной Windows SVN working copy после cutover.

Если Plugin Check или тесты обнаружат release-blocking проблему безопасности/совместимости, она оформляется отдельной задачей внутри утверждённого плана. Изменение публичного контракта потребует отдельного решения владельца.

## 7. Release model

### Рекомендуемый поток

1. Изменения проходят PR в `master`.
2. CI создаёт и проверяет кандидат ZIP, но ничего не публикует.
3. Из проверенного коммита создаётся production-тег формата `vX.Y.Z` или `v-X.Y.Z`; оба формата нормализуются в одну версию `X.Y.Z`.
4. Release workflow повторно проверяет версию и полный набор gates, воспроизводимо собирает ZIP и сохраняет checksum.
5. Workflow создаёт GitHub Release и прикрепляет тот же ZIP.
6. После успешной публикации GitHub-артефакта workflow разворачивает распакованный проверенный ZIP в WordPress.org SVN.
7. Существующий SVN-тег никогда не перезаписывается. Повторный запуск допустим только если `trunk` и существующий tag уже идентичны кандидату.

Prerelease-теги (`vX.Y.Z-beta.N`, `v-X.Y.Z-beta.N`, `vX.Y.Z-rc.N`, `v-X.Y.Z-rc.N`) могут собирать GitHub prerelease, но не публикуются в WordPress.org. Это правило и нормализация optional hyphen должны проверяться скриптом, а не только glob-паттерном workflow.

### GitHub Actions Variables, Secrets и permissions

- `vars.WPORG_USERNAME` — WordPress.org username; repository/environment variable уже создана владельцем и не читается из Secrets context;
- `secrets.WPORG_PASSWORD` — отдельный пароль/токен для SVN automation;
- встроенный `GITHUB_TOKEN` — только минимальные `contents: read` в CI и `contents: write` в release job;
- secrets доступны только production deploy job через GitHub Environment `wordpress-org`;
- логи и артефакты проверяются на отсутствие `.env`, ключей, токенов, дампов и локальных конфигов.

## 8. Тестовая стратегия

### Characterization/API

- создание глобального `$wpto` и базовые имена настроек;
- чтение raw/filtered/default values через `getOption()`;
- преобразование gallery value в массив;
- сохранение совместимости hooks и аргументов filters;
- регистрация sections/fields из существующего формата `$wpto->fields`;
- representative rendering для text, textarea, checkbox, number, select, color, photo/gallery и custom field filter;
- безопасное поведение при пустых/частично заданных options.

### WordPress integration

- чистая установка WordPress, активация плагина и отсутствие fatal error;
- тестовая тема или fixture-plugin объявляет representative fields;
- поля появляются в `Settings -> Reading`;
- сохранённые данные читаются через публичный API с ожидаемыми типами;
- проверяется upgrade/install ZIP, а не только исходная директория.

### Quality/release gates

- PHP syntax matrix для утверждённых версий PHP;
- PHPUnit/WordPress integration tests;
- WordPress Coding Standards с заранее согласованной стратегией legacy baseline/remediation;
- WordPress Plugin Check;
- authenticated admin smoke для критического сценария;
- негативные tests для ZIP hygiene, mismatch версии и небезопасного SVN status;
- двойная сборка и `cmp`/SHA-256 для доказательства воспроизводимости.

## 9. Эпики

Рекомендуемый порядок: **E1 → E2 → E3 → E4 → E5 → E6**. E2 и часть E3 можно выполнять параллельно после завершения E1, но первый execution batch будет согласован отдельно.

## E1. Канонический Git snapshot и контракт совместимости

Outcome: GitHub содержит проверенный канонический snapshot исходников и assets, а публичные контракты и релизные расхождения явно зафиксированы.

Scope:

- импорт актуального `trunk` в `plugin-dir/` и `assets` в `.wordpress-org/`;
- исключение SVN metadata и локальных файлов;
- запись SVN URL/revision и контрольных сумм импортированного snapshot;
- фиксация публичных symbols/hooks/options и отличий `trunk` от последнего SVN tag;
- согласованное исправление release metadata для будущего релиза.

Out of Scope:

- функциональная модернизация;
- импорт полной SVN-истории;
- публикация версии.

Success Criteria:

- файловое сравнение подтверждает точный импорт исходного snapshot;
- `.svn` и локальные артефакты отсутствуют в Git;
- public compatibility inventory и provenance доступны в docs;
- версия первого релиза и support policy утверждены.

Dependencies:

- утверждённый план и решения D1-D6 ниже.

Risks/Open Questions:

- `1.2.1` присутствует только в SVN trunk;
- исправления для актуального PHP могут потребовать изменения legacy edge-case поведения.

Tasking Guidance:

- Повторно применить `$decompose-work` к этому эпику с актуальным SVN snapshot и утверждёнными решениями.
- Создать задачи с обязательными полями Status, Goal, Scope, Out of Scope, DoR, DoD, AC, Dependencies и Notes/Risks.
- Назначать `needs_design`, `waiting_dependency` или `todo` по фактической готовности; не переводить работу в `todo` до выполнения DoR.

## E2. Воспроизводимое локальное Docker-окружение

Outcome: разработчик поднимает изолированный WordPress с подключённым плагином и управляет средой стабильными командами.

Scope:

- Docker Compose services `db`, `wordpress`, `wp-cli`;
- `.env.example`, именованные volumes, configurable ports/project name/PHP tag;
- setup/up/down/reset/logs/shell/test команды через Makefile;
- локальный домен `wp-site-options.local`;
- setup-симлинк `local-dev/wp-content/plugins/wp-site-options` → `/srv/web/plugin-dir`, автоматическая установка и активация плагина, test fixture с representative fields;
- инструкции для Linux, WSL2 и Docker Desktop.

Out of Scope:

- production hosting;
- обязательные HTTPS/custom domains;
- Node container без необходимости.

Success Criteria:

- clean setup выполняется одной документированной командой;
- повторный setup идемпотентен и не уничтожает данные без явного reset;
- plugin source редактируется в host `plugin-dir/` и сразу доступен WordPress через local-dev symlink;
- smoke test подтверждает активацию и доступность Settings page.

Dependencies:

- E1: канонический `plugin-dir/`.

Risks/Open Questions:

- Windows filesystem mounts могут быть медленными; рабочий Git clone рекомендуется держать внутри WSL;
- поддерживаемый PHP minimum определяет набор Docker images.

Tasking Guidance:

- Повторно применить `$decompose-work` к этому эпику после E1 с утверждённой support matrix.
- Создать execution-ready задачи со всеми обязательными атрибутами и явными destructive reset safeguards.
- Статус `todo` допустим только после утверждения версии Docker/PHP matrix.

## E3. Автоматизированные тесты и CI quality gates

Outcome: изменения не могут попасть в релиз без доказанной совместимости публичного API и базового admin workflow.

Scope:

- Composer dev/test setup;
- characterization/API tests;
- WordPress integration tests и минимальный authenticated admin smoke;
- PHP lint, coding standards strategy и Plugin Check;
- CI для pull requests и `master` с cache и загружаемыми test artifacts при сбое;
- точечные compatibility/security fixes, без которых обязательные gates не проходят.

Out of Scope:

- увеличение feature scope;
- требование 100% code coverage;
- массовый style-only rewrite legacy-кода без влияния на gate.

Success Criteria:

- CI воспроизводимо проходит на чистом runner;
- тесты фиксируют перечисленные публичные контракты;
- минимум один тест падает при намеренном нарушении ключевого контракта;
- Plugin Check не содержит блокирующих ошибок;
- support matrix задокументирована и реально запускается.

Dependencies:

- E1;
- E2 для локального integration/e2e пути;
- утверждённая support matrix.

Risks/Open Questions:

- старые прямые обращения к несуществующим array keys могут создавать warnings на актуальном PHP;
- полный WPCS на исходном legacy-коде может породить большой несодержательный diff — нужен scoped baseline/remediation подход.

Tasking Guidance:

- Повторно применить `$decompose-work`, разделив test harness, test cases, CI и remediation на атомарные задачи.
- Каждая remediation task обязана иметь regression AC на сохраняемый публичный контракт.
- Незавершённое решение о support matrix должно давать `needs_design`, а не `todo`.

## E4. Детерминированный release artifact

Outcome: из любого релизного коммита получается один проверенный, воспроизводимый и installable ZIP.

Scope:

- build и validate scripts;
- allowlist/denylist содержимого ZIP;
- нормализация timestamps и порядка файлов;
- проверка root directory, entrypoint, readme, version/changelog consistency;
- checksum и GitHub Actions artifact;
- negative tests для forbidden files и version mismatch.

Out of Scope:

- публикация в SVN;
- runtime dependencies, которых нет в исходном плагине.

Success Criteria:

- две сборки одного commit дают идентичный SHA-256;
- ZIP устанавливается через WordPress admin/WP-CLI;
- dev/test/docs/assets/secrets не попадают в ZIP;
- release version gate отвергает несогласованные metadata.

Dependencies:

- E1;
- E3 quality gates.

Risks/Open Questions:

- ошибочный exclude может удалить production-файл; структура проверяется allowlist assertions и install smoke.

Tasking Guidance:

- Повторно применить `$decompose-work`, отдельно выделив builder, validator, negative fixtures и CI integration.
- В каждой задаче определить точную команду Verification.
- Задачи публикации не включать в этот эпик.

## E5. Tag-driven GitHub и WordPress.org release

Outcome: валидный production-тег публикует проверенный артефакт в GitHub и WordPress.org без ручного копирования файлов.

Scope:

- `release.yml` на production/prerelease tag patterns;
- GitHub Release и ZIP attachment;
- SVN checkout/sync/status validation/tag/commit script;
- перенос `.wordpress-org` в SVN assets;
- idempotency, concurrency lock и dry-run tests на локальном fixture SVN;
- GitHub Environment и least-privilege secrets/permissions.

Out of Scope:

- перезапись существующих SVN tags;
- хранение паролей в репозитории;
- production deploy из branch push или pull request;
- отдельная mirror-ветка собранного плагина.

Success Criteria:

- prerelease никогда не пишет в WordPress.org SVN;
- production tag с mismatch версии останавливается до публикации;
- fixture dry-run доказывает точный sync `trunk/assets` и создание `tags/<version>`;
- existing identical tag даёт безопасный no-op, differing tag — hard fail;
- реальные credentials доступны только deploy job;
- опубликованный SVN snapshot побайтно соответствует распакованному проверенному ZIP.

Dependencies:

- E3;
- E4;
- утверждённые version/tag decisions и доступ к GitHub Actions Variables/Secrets.

Risks/Open Questions:

- Git tag является production-командой; ошибочно созданный тег нельзя считать безвредным;
- сбой между GitHub Release и SVN commit требует идемпотентного rerun;
- WordPress.org может отклонить metadata или Plugin Check findings, которые локально были warning-level.

Tasking Guidance:

- Повторно применить `$decompose-work`, разделив workflow, deploy script, fixture tests, secret configuration и dry-run.
- Secret configuration держать `waiting_dependency`, пока владелец не добавит credentials.
- Реальный SVN commit не переводить в `todo` до успешного dry-run и явного approval первого execution release batch.

## E6. Cutover, первая публикация и runbook

Outcome: команда разработки переведена на GitHub-first процесс, а первый автоматизированный релиз проверен end-to-end.

Scope:

- development/release/recovery runbooks;
- настройка branch/tag protections и required checks;
- GitHub Actions Variables/Secrets/Environment checklist;
- dry-run against real WordPress.org checkout без commit;
- первый production release и post-release verification;
- перевод Windows SVN working copy в резервный/read-only инструмент, а не источник разработки.

Out of Scope:

- удаление исторической SVN working copy;
- ретроспективная публикация отсутствующего `1.2.1` tag без отдельного решения;
- новые продуктовые возможности.

Success Criteria:

- новый разработчик проходит documented setup и CI flow;
- dry-run не содержит неожиданных удалений/добавлений;
- первый GitHub Release, WordPress.org `trunk`, `assets` и новый SVN tag согласованы;
- installation/update smoke проходит на опубликованном артефакте;
- recovery/rerun процедура проверена и задокументирована.

Dependencies:

- E1-E5;
- WordPress.org credentials;
- явное approval на первый production tag.

Risks/Open Questions:

- старый trunk содержит версию без соответствующего tag;
- propagation WordPress.org update может занять время и требует повторной post-release проверки.

Tasking Guidance:

- Повторно применить `$decompose-work`, отдельно выделив protections, secrets, dry-run, production release и post-release QA.
- Первый реальный deploy должен оставаться `waiting_dependency` до human approval.
- Закрыть эпик только после независимой проверки опубликованных GitHub/SVN артефактов.

## 10. Утверждённые решения владельца

### D1. Первая автоматизированная версия

**Утверждено: `1.2.2`.** Она однозначно следует за `1.2.1` из SVN trunk и позволяет исправить `Stable tag`, не создавая задним числом спорный tag.

### D2. Минимальная поддерживаемая матрица

**Утверждено:** для нового maintenance-релиза объявить современный проверяемый минимум (ориентир WordPress 6.0+ и PHP 7.4+) и проверять этот минимум плюс актуальные стабильные WordPress/PHP на дату реализации. Точные верхние версии фиксируются после compatibility audit.

### D3. Production trigger

**Утверждено:** push валидного тега `vX.Y.Z` или `v-X.Y.Z` считается явным production intent; оба формата нормализуются в `X.Y.Z`. После обязательных gates workflow автоматически создаёт GitHub Release и пишет в WordPress.org SVN. Prerelease-варианты обоих форматов собираются без SVN deploy.

### D4. Граница модернизации

**Утверждено:** сохранить публичный API и выполнить только те compatibility/security fixes, которые нужны для прохождения утверждённой матрицы и release gates. Более широкая переработка остаётся вне первого цикла.

### D5. Репозиторий и local development

**Утверждено:** основная ветка — `master`; локальный домен — `wp-site-options.local`; `plugin-dir/` остаётся каноническим source directory и подключается в local-dev WordPress через симлинк.

### D6. GitHub Actions configuration

**Утверждено:** WordPress.org username читается из `vars.WPORG_USERNAME`; переменная уже создана владельцем. Пароль читается отдельно из `secrets.WPORG_PASSWORD` и не записывается в repository variables или файлы.

## 11. Риски и меры контроля

| Риск | Контроль |
|---|---|
| Потеря отличий SVN trunk | provenance, checksums и побайтовое сравнение snapshot |
| Случайное включение `.svn`, дампов или secrets | denylist validator, ZIP negative tests, artifact inspection |
| Регрессия публичного API при PHP compatibility fixes | characterization tests до remediation |
| Случайная публикация по тегу | строгий формат/metadata gate, protected tags, release checklist |
| Частичный релиз GitHub/SVN | один immutable ZIP, idempotent deploy, concurrency lock, recovery runbook |
| Перезапись существующего SVN tag | hard fail при любом несовпадении; identical state — no-op |
| Большой шум от style modernization | scoped baseline и только release-blocking remediation |
| Расхождение локального Docker и CI | общие test/build scripts, одинаковые команды в Makefile и Actions |

## 12. Backlog и следующий шаг

План декомпозирован через `$decompose-work` в [execution backlog](./execution-backlog.md). Задачи содержат Status, Goal, Scope, Out of Scope, DoR, DoD, AC, Dependencies, Notes/Risks и Verification.

Рекомендуемый первый execution batch — T1, импорт чистого SVN snapshot и создание durable canonical source commit. Реализация начнётся только после отдельного одобрения этого batch. Его завершение разблокирует T2; после commit выполняется readiness sweep. E2 и E3 открываются параллельно только после независимого QA E1.
