# Use bash for better scripting
SHELL := /bin/bash
.DEFAULT_GOAL := up

# Folders we need
DIRS := quazr-caddy/config quazr-caddy/data quazr-adminboard quazr-data

.PHONY: prepare up down restart logs ps clean help

prepare:
	@echo "➡️  Checking user permissions..."
	@if [ "$$(id -u)" -eq 0 ]; then \
		echo "❌  Do not run this as root (or with sudo)!"; \
		echo "    Run as a regular user to avoid permission issues."; \
		exit 1; \
	fi
	@echo "✅  Running as non-root user."

	@echo "➡️  Checking for .env file..."
	@if [ ! -f .env ]; then \
		echo "❌  .env file not found!"; \
		echo "    Please create one before running 'make up'."; \
		exit 1; \
	fi
	@echo "✅  .env file found."

	@echo "➡️  Checking for Caddyfile..."
	@if [ ! -f quazr-caddy/Caddyfile ]; then \
		echo "❌  quazr-caddy/Caddyfile not found!"; \
		echo "    Please create one before running 'make up'."; \
		exit 1; \
	fi
	@echo "✅  Caddyfile found."

	@echo "➡️  Creating required directories..."
	@for d in $(DIRS); do \
		if [ ! -d $$d ]; then \
			echo "📁  Creating $$d"; \
			mkdir -p $$d; \
		else \
			echo "✔️  $$d already exists"; \
		fi; \
	done
	@echo "✅  Directory check complete."

up: prepare
	@echo "➡️  Starting Docker Compose..."
	@sudo docker compose up -d
	@echo "✅ Services started."

down:
	@sudo docker compose down

restart:
	@$(MAKE) down
	@$(MAKE) up

logs:
	@sudo docker compose logs -f --tail=100

ps:
	@sudo docker compose ps

clean: down
	@echo "⚠️  Not removing data directories by default."

nuke: down
	@echo "⚠️  Removing data directories!"
	@rm -rf $(DIRS)

help:
	@echo "make up        - create dirs and start docker compose"
	@echo "make down      - stop and remove containers"
	@echo "make restart   - restart the stack"
	@echo "make logs      - tail logs"
	@echo "make ps        - show container status"
	@echo "make clean     - stop stack (does not delete data dirs)"
	@echo "make nuke      - stop stack and nuke the directories"
