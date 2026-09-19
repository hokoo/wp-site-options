DOCKER_COMPOSE ?= docker compose

.DEFAULT_GOAL := help

.PHONY: help require-env setup up down reset ps db.up php.up nginx.up php.build \
	logs php.log php.log.clear shell php-shell nginx-shell db-shell wp \
	composer.install test lint test-e2e hosts-check hosts-add hosts-remove \
	release-zip test-release test-svn test-release-tags test-release-contracts

help:
	@printf '%s\n' \
		'make setup  - build and reconcile the complete local WordPress site' \
		'make up     - start db, PHP-FPM, and nginx and wait for health checks' \
		'make down   - stop the stack and preserve local data' \
		'make reset  - explicitly remove this project local data' \
		'make ps     - show this Compose project services' \
		'make php.build - rebuild the local Wodby PHP image' \
		'make logs [SERVICE=php] - follow Docker service logs' \
		'make php.log - follow the colorized PHP application error log' \
		'make php.log.clear - truncate PHP application logs' \
		'make shell  - open a shell in the PHP container' \
		'make nginx-shell - open a shell in the nginx container' \
		'make db-shell - open the MySQL client in the db container' \
		'make wp ARGS="plugin list" - run WP-CLI in the PHP container' \
		'make composer.install - install PHP development dependencies in PHP' \
		'make lint   - run PHP syntax checks in PHP' \
		'make test   - run unit tests in PHP' \
		'make test-e2e - start the site and run the browser smoke on the host' \
		'make hosts-check - verify the local-domain mapping' \
		'make hosts-add - add the local-domain mapping' \
		'make hosts-remove - remove the mapping managed by this project' \
		'make release-zip - build and validate the deterministic plugin ZIP' \
		'make test-release - run release reproducibility and negative tests' \
		'make test-svn - run isolated local SVN deployment fixtures' \
		'make test-release-tags - run the production/prerelease tag parser table' \
		'make test-release-contracts - run tag parser and SVN deployment contracts'

require-env:
	@test -f .env || { printf 'Missing .env; run make setup first.\n' >&2; exit 1; }

setup: hosts-add
	./scripts/setup-local.sh

db.up: require-env
	$(DOCKER_COMPOSE) up -d --wait db

php.up: require-env
	$(DOCKER_COMPOSE) up -d --wait db php

nginx.up: require-env
	$(DOCKER_COMPOSE) up -d --wait db php nginx

up: nginx.up

down: require-env
	$(DOCKER_COMPOSE) down

reset:
	./scripts/reset-local.sh

ps: require-env
	$(DOCKER_COMPOSE) ps

php.build: require-env
	$(DOCKER_COMPOSE) build --pull php

logs: require-env
	$(DOCKER_COMPOSE) up -d db php nginx
	$(DOCKER_COMPOSE) logs --follow --tail=100 --timestamps $(SERVICE)

php.log: php.up
	$(DOCKER_COMPOSE) exec -T php sh -lc \
		'touch /var/log/php/error.log && tail -n 50 -F /var/log/php/error.log | PYTHONUNBUFFERED=1 grcat /home/wodby/.grc/grc.php.log.conf'

php.log.clear: php.up
	$(DOCKER_COMPOSE) exec -T php sh -lc \
		'for log_file in /var/log/php/*.log; do [ -e "$${log_file}" ] || continue; : > "$${log_file}"; done'

shell: php-shell

php-shell: php.up
	$(DOCKER_COMPOSE) exec php bash

nginx-shell: nginx.up
	$(DOCKER_COMPOSE) exec nginx sh

db-shell: db.up
	$(DOCKER_COMPOSE) exec db sh -lc 'MYSQL_PWD="$${MYSQL_ROOT_PASSWORD}" mysql --user=root "$${MYSQL_DATABASE}"'

wp: php.up
	$(DOCKER_COMPOSE) exec -T php wp $(ARGS)

composer.install: php.up
	$(DOCKER_COMPOSE) exec -T --workdir /workspace php composer install

test: php.up
	$(DOCKER_COMPOSE) exec -T --workdir /workspace php composer test

lint: php.up
	$(DOCKER_COMPOSE) exec -T --workdir /workspace php composer lint:php

test-e2e: nginx.up
	npm run test:e2e

hosts-check:
	./scripts/local-domain.sh check

hosts-add:
	./scripts/local-domain.sh add

hosts-remove:
	./scripts/local-domain.sh remove

release-zip:
	./scripts/build-release-zip.sh

test-release:
	./scripts/test-release-artifact.sh

test-svn:
	./scripts/test-svn-deploy.sh

test-release-tags:
	./scripts/test-release-tags.sh

test-release-contracts: test-release-tags test-svn
