DOCKER_COMPOSE ?= docker compose
COMPOSER_BIN ?= composer

.DEFAULT_GOAL := help

.PHONY: help setup up down reset logs shell test lint test-e2e

help:
	@printf '%s\n' \
		'make setup  - create or reconcile the local WordPress site' \
		'make up     - start the existing Compose stack' \
		'make down   - stop the stack and preserve local data' \
		'make reset  - explicitly remove this project local data' \
		'make logs   - follow service logs' \
		'make shell  - open a WP-CLI container shell' \
		'make lint   - run PHP syntax checks' \
		'make test   - run unit tests' \
		'make test-e2e - run the authenticated admin browser smoke'

setup:
	./scripts/setup-local.sh

up:
	@test -f .env || { printf 'Missing .env; run make setup first.\n' >&2; exit 1; }
	$(DOCKER_COMPOSE) up -d --wait

down:
	@test -f .env || { printf 'Missing .env; refusing to guess the Compose project.\n' >&2; exit 1; }
	$(DOCKER_COMPOSE) down

reset:
	./scripts/reset-local.sh

logs:
	@test -f .env || { printf 'Missing .env; run make setup first.\n' >&2; exit 1; }
	$(DOCKER_COMPOSE) logs --follow --tail=100

shell:
	@test -f .env || { printf 'Missing .env; run make setup first.\n' >&2; exit 1; }
	$(DOCKER_COMPOSE) exec wp-cli sh

test:
	$(COMPOSER_BIN) test

test-e2e:
	npm run test:e2e

lint:
	$(COMPOSER_BIN) lint:php
