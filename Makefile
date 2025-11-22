# Makefile for Semantic Graph Project

.PHONY: help setup start stop restart logs clean test

help: ## Show this help message
	@echo "Semantic Graph - Hybrid Elixir/Ash + Graphiti"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

setup: ## Initial setup - install dependencies
	@echo "Setting up project..."
	cd semantic_graph && mix deps.get
	cd graphiti_service && python -m venv venv && . venv/bin/activate && pip install -r requirements.txt
	cp .env.docker .env
	@echo "Setup complete! Edit .env with your API keys."

start: ## Start all services with Docker Compose
	@echo "Starting services..."
	docker-compose up -d
	@echo "Services started!"
	@echo "Neo4j Browser: http://localhost:7474"
	@echo "Graphiti API: http://localhost:8000/docs"

stop: ## Stop all services
	@echo "Stopping services..."
	docker-compose down

restart: ## Restart all services
	@echo "Restarting services..."
	docker-compose restart

logs: ## View logs from all services
	docker-compose logs -f

logs-neo4j: ## View Neo4j logs
	docker-compose logs -f neo4j

logs-graphiti: ## View Graphiti service logs
	docker-compose logs -f graphiti

clean: ## Remove containers and volumes
	@echo "Cleaning up..."
	docker-compose down -v
	@echo "Cleanup complete!"

test: ## Run tests
	cd semantic_graph && mix test

test-integration: ## Run integration tests
	cd semantic_graph && mix test --only integration

elixir-shell: ## Start Elixir IEx shell
	cd semantic_graph && iex -S mix

elixir-run: ## Run the Elixir application
	cd semantic_graph && mix run --no-halt

graphiti-shell: ## Start Python shell with Graphiti client
	cd graphiti_service && . venv/bin/activate && python

health: ## Check health of all services
	@echo "Checking Neo4j..."
	@curl -s http://localhost:7474 > /dev/null && echo "✓ Neo4j is running" || echo "✗ Neo4j is not responding"
	@echo "Checking Graphiti..."
	@curl -s http://localhost:8000/health | python -m json.tool || echo "✗ Graphiti is not responding"

build: ## Build Docker images
	docker-compose build

rebuild: ## Rebuild Docker images without cache
	docker-compose build --no-cache

# Development targets
dev-neo4j: ## Start only Neo4j for local development
	docker-compose up -d neo4j

dev-graphiti: ## Run Graphiti locally (requires Neo4j running)
	cd graphiti_service && . venv/bin/activate && uvicorn main:app --reload

dev-elixir: ## Run Elixir app locally (requires Graphiti running)
	cd semantic_graph && iex -S mix phx.server
