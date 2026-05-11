# Use bash for better scripting
SHELL := /bin/bash
.DEFAULT_GOAL := help

DIRS := quazr-authboard 

GH_TOKEN := $(shell grep -E '^GH_TOKEN=' .env | cut -d '=' -f2- | tr -d '\r' | xargs)

.PHONY: setup validate-tools validate-user validate-env validate-token schema postgresql pgadmin frontend backend rabbitmq rustfs sharp caddy init up down restart logs ps prune prune-all health help

setup:
	@if [ -z "$(SERVICE)" ]; then \
		echo "Error: SERVICE parameter is required"; \
		exit 1; \
	fi
	@echo "❚  Setting up $(SERVICE) service..."
	@if [ ! -z "$(REPOSITORY)" ] && [ ! -z "$(MAINTAINER)" ]; then \
		echo "    ♦  Validating service repository..."; \
		if [ ! -d "$(REPOSITORY)/.git" ]; then \
			REPOSITORY_URL=https://$(GH_TOKEN):x-oauth-basic@github.com/$(MAINTAINER)/$(REPOSITORY).git; \
			echo "        ⤓  Cloning $(REPOSITORY) from github.com/$(MAINTAINER)/$(REPOSITORY).git..."; \
			git clone "$$REPOSITORY_URL" "$(REPOSITORY)" \
				|| { echo "        ❌  Failed to clone $(REPOSITORY)."; exit 1; }; \
		else \
			echo "        ✔️  $(REPOSITORY) already present."; \
		fi; \
	fi
	@if [ ! -z "$(DIRECTORY)" ] || [ ! -z "$(SUB_DIRECTORIES)" ]; then \
		echo "    ♦  Validating required directories..."; \
		for dir in $(DIRECTORY) $(SUB_DIRECTORIES); do \
			if [ ! -d $$dir ]; then \
				echo "        ◞  Creating $$dir..."; \
				mkdir $$dir; \
			else \
				echo "        ✔️  $$dir already exists."; \
			fi; \
		done; \
		if [ ! -z "$(PERMISSIONS)" ]; then \
			echo "    ♦  Validating directory permissions..."; \
			for dir in $(DIRECTORY) $(SUB_DIRECTORIES); do \
				CURRENT_PERMISSIONS=$$(stat -c '%a' $$dir); \
				if [ "$$CURRENT_PERMISSIONS" != "$(PERMISSIONS)" ]; then \
					echo "        ◞  Updating permissions for $$dir ($$CURRENT_PERMISSIONS → $(PERMISSIONS))..."; \
					sudo chmod $(PERMISSIONS) $$dir; \
				else \
					echo "        ✔️  $$dir permissions already correct ($(PERMISSIONS))."; \
				fi; \
			done; \
		fi; \
		if [ ! -z "$(OWNER)" ]; then \
			echo "    ♦  Validating directory ownership..."; \
			for dir in $(DIRECTORY) $(SUB_DIRECTORIES); do \
				CURRENT_OWNER=$$(stat -c '%u:%g' $$dir); \
				if [ "$$CURRENT_OWNER" != "$(OWNER)" ]; then \
					echo "        ◞  Updating ownership for $$dir ($$CURRENT_OWNER → $(OWNER))..."; \
					sudo chown $(OWNER) $$dir; \
				else \
					echo "        ✔️  $$dir ownership already correct ($(OWNER))."; \
				fi; \
			done; \
		fi; \
	fi
	@echo "    ✔️  $(SERVICE) setup complete."

validate-tools:
	@echo "❚  Checking required tools..."
	@if ! command -v git >/dev/null 2>&1; then \
		echo "    ❌  git is not installed or not in PATH."; exit 1; \
	fi
	@if ! docker --version >/dev/null 2>&1; then \
		echo "    ❌  docker is not installed or not in PATH."; exit 1; \
	fi
	@if ! docker compose version >/dev/null 2>&1; then \
		echo "    ❌  docker compose plugin is not installed."; exit 1; \
	fi
	@echo "    ✔️  Tools OK."

validate-user:
	@echo "❚  Checking user permissions..."
	@if [ "$$(id -u)" -eq 0 ]; then \
		echo "    ❌  Do not run this as root (or with sudo)!"; \
		echo "        Run as a regular user to avoid permission issues."; \
		exit 1; \
	fi
	@echo "    ✔️  Running as non-root user."

validate-env:
	@echo "❚  Checking for .env file..."
	@if [ ! -f .env ]; then \
		echo "    ❌  .env file not found!"; \
		echo "        Please create one before running 'make up'."; \
		exit 1; \
	fi
	@echo "    ✔️  .env file found."

validate-token:
	@echo "❚  Reading GH_TOKEN from .env..."
	@if [ -z "$(GH_TOKEN)" ]; then \
		echo "    ❌  GH_TOKEN not found or empty in .env"; \
		exit 1; \
	fi

SCHEMA_DIRECTORY := quazr-db
SCHEMA_REPOSITORY := quazr-db
SCHEMA_DIRECTORY_PERMISSIONS := 755
SCHEMA_DIRECTORY_OWNER := 1000:1000
SCHEMA_REPOSITORY_MAINTAINER := vipolar
schema: validate-token
	$(MAKE) --no-print-directory setup SERVICE=Schema DIRECTORY=$(SCHEMA_DIRECTORY) PERMISSIONS=$(SCHEMA_DIRECTORY_PERMISSIONS) OWNER=$(SCHEMA_DIRECTORY_OWNER) REPOSITORY=$(SCHEMA_REPOSITORY) MAINTAINER=$(SCHEMA_REPOSITORY_MAINTAINER);

POSTGRESQL_DIRECTORY := quazr-data
POSTGRESQL_DIRECTORY_PERMISSIONS := 700
POSTGRESQL_DIRECTORY_OWNER := 999:1000
postgresql:
	$(MAKE) --no-print-directory setup SERVICE=PostgreSQL DIRECTORY=$(POSTGRESQL_DIRECTORY) PERMISSIONS=$(POSTGRESQL_DIRECTORY_PERMISSIONS) OWNER=$(POSTGRESQL_DIRECTORY_OWNER);

PGADMIN_DIRECTORY := quazr-adminboard
PGADMIN_DIRECTORY_PERMISSIONS := 755
PGADMIN_DIRECTORY_OWNER := 5050:5050
pgadmin:
	$(MAKE) --no-print-directory setup SERVICE=pgAdmin DIRECTORY=$(PGADMIN_DIRECTORY) PERMISSIONS=$(PGADMIN_DIRECTORY_PERMISSIONS) OWNER=$(PGADMIN_DIRECTORY_OWNER);

FRONTEND_DIRECTORY := quazr-sk
FRONTEND_DIRECTORY_PERMISSIONS := 755
FRONTEND_DIRECTORY_OWNER := 1000:1000
FRONTEND_REPOSITORY := quazr-sk
FRONTEND_REPOSITORY_MAINTAINER := vipolar
FRONTEND_SUB_DIRECTORIES := $(FRONTEND_DIRECTORY)/node_modules
frontend: validate-token
	$(MAKE) --no-print-directory setup SERVICE=Frontend DIRECTORY=$(FRONTEND_DIRECTORY) SUB_DIRECTORIES="$(FRONTEND_SUB_DIRECTORIES)" PERMISSIONS=$(FRONTEND_DIRECTORY_PERMISSIONS) OWNER=$(FRONTEND_DIRECTORY_OWNER) REPOSITORY=$(FRONTEND_REPOSITORY) MAINTAINER=$(FRONTEND_REPOSITORY_MAINTAINER);

BACKEND_DIRECTORY := quazr-backend
BACKEND_DIRECTORY_PERMISSIONS := 755
BACKEND_DIRECTORY_OWNER := 1000:1000
BACKEND_REPOSITORY := quazr-backend
BACKEND_REPOSITORY_MAINTAINER := vipolar
BACKEND_SUB_DIRECTORIES := $(BACKEND_DIRECTORY)/.repository
backend: validate-token
	$(MAKE) --no-print-directory setup SERVICE=Backend DIRECTORY=$(BACKEND_DIRECTORY) SUB_DIRECTORIES="$(BACKEND_SUB_DIRECTORIES)" PERMISSIONS=$(BACKEND_DIRECTORY_PERMISSIONS) OWNER=$(BACKEND_DIRECTORY_OWNER) REPOSITORY=$(BACKEND_REPOSITORY) MAINTAINER=$(BACKEND_REPOSITORY_MAINTAINER);

RABBITMQ_DIRECTORY := quazr-rabbitmq
RABBITMQ_DIRECTORY_PERMISSIONS := 755
RABBITMQ_DIRECTORY_OWNER := 1000:1000
RABBITMQ_SUB_DIRECTORIES := "$(RABBITMQ_DIRECTORY)/data $(RABBITMQ_DIRECTORY)/logs"
rabbitmq:
	$(MAKE) --no-print-directory setup SERVICE=RabbitMQ DIRECTORY=$(RABBITMQ_DIRECTORY) SUB_DIRECTORIES=$(RABBITMQ_SUB_DIRECTORIES) PERMISSIONS=$(RABBITMQ_DIRECTORY_PERMISSIONS) OWNER=$(RABBITMQ_DIRECTORY_OWNER);

RUSTFS_DIRECTORY := quazr-rustfs3
RUSTFS_DIRECTORY_PERMISSIONS := 755
RUSTFS_DIRECTORY_OWNER := 10001:10001
RUSTFS_SUB_DIRECTORIES := "$(RUSTFS_DIRECTORY)/data $(RUSTFS_DIRECTORY)/logs"
rustfs:
	$(MAKE) --no-print-directory setup SERVICE=RustFS DIRECTORY=$(RUSTFS_DIRECTORY) SUB_DIRECTORIES=$(RUSTFS_SUB_DIRECTORIES) PERMISSIONS=$(RUSTFS_DIRECTORY_PERMISSIONS) OWNER=$(RUSTFS_DIRECTORY_OWNER);

SHARP_DIRECTORY := quazr-sharp
SHARP_DIRECTORY_PERMISSIONS := 755
SHARP_DIRECTORY_OWNER := 1000:1000
SHARP_REPOSITORY := quazr-sharp
SHARP_REPOSITORY_MAINTAINER := vipolar
SHARP_SUB_DIRECTORIES := $(SHARP_DIRECTORY)/node_modules
sharp: validate-token
	$(MAKE) --no-print-directory setup SERVICE=Sharp DIRECTORY=$(SHARP_DIRECTORY) SUB_DIRECTORIES="$(SHARP_SUB_DIRECTORIES)" PERMISSIONS=$(SHARP_DIRECTORY_PERMISSIONS) OWNER=$(SHARP_DIRECTORY_OWNER) REPOSITORY=$(SHARP_REPOSITORY) MAINTAINER=$(SHARP_REPOSITORY_MAINTAINER);

CADDY_DIRECTORY := quazr-caddy
CADDY_DIRECTORY_PERMISSIONS := 755
CADDY_DIRECTORY_OWNER := 1000:1000
CADDY_SUB_DIRECTORIES := $(CADDY_DIRECTORY)/config $(CADDY_DIRECTORY)/data
caddy:
	$(MAKE) --no-print-directory setup SERVICE=Caddy DIRECTORY=$(CADDY_DIRECTORY) SUB_DIRECTORIES="$(CADDY_SUB_DIRECTORIES)" PERMISSIONS=$(CADDY_DIRECTORY_PERMISSIONS) OWNER=$(CADDY_DIRECTORY_OWNER);

init: validate-tools validate-user validate-env validate-token schema postgresql pgadmin frontend backend rabbitmq rustfs sharp caddy

up: init
	@echo "❚  Checking for Caddyfile..."
	@if [ ! -f $(CADDY_DIRECTORY)/Caddyfile ]; then \
		echo "    ❌  $(CADDY_DIRECTORY)/Caddyfile not found!"; \
		echo "        Please create one before running 'make up.'"; \
		exit 1; \
	fi
	@echo "    ✔️  Caddyfile present."
	@echo "❚  Starting Docker Compose..."
	@sudo docker compose --profile observability up -d
	@echo "✨  Services started."

down:
	@sudo docker compose down --remove-orphans

restart:
	@$(MAKE) down
	@$(MAKE) up

logs:
	@sudo docker compose logs -f --tail=100

ps:
	@sudo docker compose ps

prune: down
	@echo "⚠️  Pruning dangling Docker resources (no volumes)..."
	@echo "⚠️  Not removing data directories by default."
	@sudo docker image prune -f
	@sudo docker container prune -f
	@sudo docker network prune -f
	@echo "    ✔️  Prune complete."

prune-all: down
	@echo "⚠️  Aggressive prune will remove unused VOLUMES (data loss risk)."
	@read -p 'Type "YES" to continue: ' ans; \
	if [ "$$ans" = "YES" ]; then \
		sudo docker system prune -af --volumes; \
	else \
		echo "    ✘  Cancelled."; \
	fi

health:
	@sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

help:
	@echo "make up            - create dirs and start docker compose"
	@echo "make down          - stop and remove containers"
	@echo "make restart       - restart the stack"
	@echo "make logs          - tail logs"
	@echo "make ps            - show container status"
	@echo "make prune         - prune dangling docker resources (safe)"
	@echo "make prune-all     - aggressive prune (includes volumes; DATA LOSS!)"
	@echo "make rm-repos      - delete cloned repositories (data loss risk)"
	@echo "make rm-dirs       - delete data directories (data loss risk)"
	@echo "make nuke          - nuke all data (data loss risk)"
