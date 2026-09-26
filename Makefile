# Makefile for Semantic Graph Project

.PHONY: help setup start stop restart logs clean test test-all db-setup db-reset health

help: ## Show this help message
	@echo "Semantic Graph - Elixir/Ash on PostgreSQL"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

setup: ## Initial setup - dependencies, database, schema
	@echo "Setting up project..."
	cp -n .env.docker .env || true
	cd semantic_graph && mix deps.get && mix ecto.create && mix ecto.migrate
	@echo "Setup complete! Edit .env with your API keys."

start: ## Start PostgreSQL with Docker Compose
	docker compose up -d
	@echo "PostgreSQL listening on localhost:5432"

stop: ## Stop services
	docker compose down

restart: ## Restart services
	docker compose restart

logs: ## View logs
	docker compose logs -f

clean: ## Remove containers and volumes (destroys the graph)
	docker compose down -v

db-setup: ## Create the database and run migrations
	cd semantic_graph && mix ecto.create && mix ecto.migrate

db-reset: ## Drop, recreate and migrate the database
	cd semantic_graph && mix ecto.reset

test: ## Run the suite (creates and migrates the test database first)
	cd semantic_graph && mix test

test-all: ## Run the canonical local test gates
	cd semantic_graph && mix test
	cd semantic_graph && MIX_ENV=test mix gleam.test
	cd auto_agent && mix compile

health: ## Check PostgreSQL is reachable
	@pg_isready -h $${PGHOST:-localhost} -p $${PGPORT:-5432} -U $${PGUSER:-postgres} \
	  && echo "✓ PostgreSQL is running" || echo "✗ PostgreSQL is not responding"

elixir-shell: ## Start Elixir IEx shell
	cd semantic_graph && iex -S mix

elixir-run: ## Run the Elixir application
	cd semantic_graph && mix run --no-halt

dev-postgres: ## Start only PostgreSQL
	docker compose up -d postgres
