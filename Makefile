.DEFAULT_GOAL := help
COMPOSE := docker compose

.PHONY: help up down logs restart clean check test deps

help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

up: ## Build and start everything (frontend on :3000, API on :8000)
	$(COMPOSE) up --build -d
	@echo ""
	@echo "  frontend  http://localhost:3000"
	@echo "  api       http://localhost:8000/api/health"
	@echo "  docs      http://localhost:8000/docs"
	@echo ""
	@echo "  Waiting for the API to answer..."
	@for i in $$(seq 1 60); do \
		if curl -fsS http://localhost:8000/api/health >/dev/null 2>&1; then \
			echo "  API is up."; exit 0; \
		fi; sleep 2; \
	done; \
	echo "  API did not come up in 120s. Run 'make logs'."; exit 1

deps: ## Install deps after editing package.json or requirements.txt
	$(COMPOSE) exec web npm install
	$(COMPOSE) exec api pip install -r requirements.txt
	$(COMPOSE) restart api

down: ## Stop everything (keeps the database volume)
	$(COMPOSE) down

logs: ## Tail logs from all services
	$(COMPOSE) logs -f

restart: ## Restart the API container
	$(COMPOSE) restart api

clean: ## Stop everything and delete volumes (wipes the database and uploads)
	$(COMPOSE) down -v

check: ## Typecheck the frontend
	$(COMPOSE) exec web npm run typecheck

test: ## Run backend tests
	$(COMPOSE) exec api python -m pytest -q
