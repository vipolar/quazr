# Use bash for better scripting
SHELL := /bin/bash
.DEFAULT_GOAL := help

# Folders we need
DIRS := quazr-adminboard quazr-caddy/config quazr-caddy/data quazr-data
REPOS := quazr-db quazr-sk
MAINTAINER := vipolar

.PHONY: initialize check-tools check-user check-env make-dirs clone-repos check-caddyfile up down restart logs ps prune prune-all rm-repos rm-dirs nuke help

initialize: check-tools check-user check-env make-dirs clone-repos
	@echo "✅  initialization complete."

check-tools:
	@echo "➡️  Checking required tools..."
	@if ! command -v git >/dev/null 2>&1; then \
		echo "❌  git is not installed or not in PATH."; exit 1; \
	fi
	@if ! docker --version >/dev/null 2>&1; then \
		echo "❌  docker is not installed or not in PATH."; exit 1; \
	fi
	@if ! docker compose version >/dev/null 2>&1; then \
		echo "❌  docker compose plugin is not installed."; exit 1; \
	fi
	@echo "✅  Tools OK."

check-user:
	@echo "➡️  Checking user permissions..."
	@if [ "$$(id -u)" -eq 0 ]; then \
		echo "❌  Do not run this as root (or with sudo)!"; \
		echo "    Run as a regular user to avoid permission issues."; \
		exit 1; \
	fi
	@echo "✅  Running as non-root user."

check-env:
	@echo "➡️  Checking for .env file..."
	@if [ ! -f .env ]; then \
		echo "❌  .env file not found!"; \
		echo "    Please create one before running 'make up'."; \
		exit 1; \
	fi
	@echo "✅  .env file found."

make-dirs:
	@echo "➡️  Creating required directories..."
	@for dir in $(DIRS); do \
		if [ ! -d $$dir ]; then \
			echo "📁  Creating $$dir"; \
			mkdir -p $$dir; \
		else \
			echo "✔️  $$dir already exists"; \
		fi; \
	done
	@echo "✅  Directory check complete."

clone-repos:
	@echo "➡️  Reading GH_TOKEN from .env..."
	@GH_TOKEN=$$(grep -E '^GH_TOKEN=' .env | cut -d '=' -f2- | tr -d '\r' | xargs); \
	if [ -z "$$GH_TOKEN" ]; then \
		echo "❌  GH_TOKEN not found or empty in .env"; \
		exit 1; \
	fi; \
	for repo in $(REPOS); do \
		if [ ! -d "$$repo/.git" ]; then \
			echo "➡️  Cloning $$repo from github.com/$(MAINTAINER)/$$repo.git ..."; \
			git clone "https://$${GH_TOKEN}:x-oauth-basic@github.com/$(MAINTAINER)/$$repo.git" "$$repo" \
				|| { echo "❌  Failed to clone $$repo"; exit 1; }; \
		else \
			echo "✔️  $$repo already present (skipping clone)"; \
		fi; \
	done
	@echo "✅  Repo check complete."

check-caddyfile:
	@echo "➡️  Checking for Caddyfile..."
	@if [ ! -f quazr-caddy/Caddyfile ]; then \
		echo "❌  quazr-caddy/Caddyfile not found!"; \
		echo "    Please create one before running 'make up'."; \
		exit 1; \
	fi
	@echo "✅  Caddyfile found."

up: initialize check-caddyfile
	@echo "➡️  Starting Docker Compose..."
	@sudo docker compose up -d
	@echo "✅ Services started."

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
	@echo "✅  Prune complete."

prune-all: down
	@echo "🛑  Aggressive prune will remove unused VOLUMES (data loss risk)."
	@read -p 'Type "YES" to continue: ' ans; \
	if [ "$$ans" = "YES" ]; then \
		sudo docker system prune -af --volumes; \
	else \
		echo "Cancelled."; \
	fi

rm-repos: down
	@echo "⚠️  Removing cloned repositories!"
	@read -p 'Type "YES" to continue: ' ans; \
	if [ "$$ans" = "YES" ]; then \
		rm -rf -- $(REPOS); \
	else \
		echo "Cancelled."; \
	fi

rm-dirs: down
	@echo "⚠️  Removing data directories!"
	@read -p 'Type "YES" to continue: ' ans; \
	if [ "$$ans" = "YES" ]; then \
		rm -rf -- $(DIRS); \
	else \
		echo "Cancelled."; \
	fi

nuke: prune-all rm-repos rm-dirs

help:
	@echo "make up            - create dirs and start docker compose"
	@echo "make down          - stop and remove containers"
	@echo "make restart       - restart the stack"
	@echo "make logs          - tail logs"
	@echo "make ps            - show container status"
	@echo "make prune         - prune dangling docker resources (safe)"
	@echo "make prune-all     - aggressive prune (includes volumes; DATA LOSS!)"
	@echo "make rm-repos      - Delete cloned repositories"
	@echo "make rm-dirs       - Delete data directories"
	@echo "make nuke          - Nuke all data"
