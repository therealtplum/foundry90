# ======================================================================
# Makefile for Financial/Macro Data Hub (DB utilities)
# ======================================================================

DOCKER_COMPOSE = docker compose
DB_CONTAINER = fmhub_db
DB_USER = app
DB_NAME = fmhub

SCHEMA_FILE = services/db/schema.sql

# ----------------------------------------------------------------------
# Start only Postgres + Redis (useful for local dev)
# ----------------------------------------------------------------------
db-up:
	$(DOCKER_COMPOSE) up -d db redis

# ----------------------------------------------------------------------
# Stop DB + Redis
# ----------------------------------------------------------------------
db-down:
	$(DOCKER_COMPOSE) stop db redis

# ----------------------------------------------------------------------
# Drop + recreate the entire Postgres database (dangerous)
# ----------------------------------------------------------------------
db-reset:
	@echo "🔴 WARNING: This will DROP and RECREATE the database $(DB_NAME)"
	@read -p "Continue? (y/N) " confirm && if [ "$$confirm" = "y" ]; then \
		$(DOCKER_COMPOSE) exec db psql -U $(DB_USER) -d postgres -c "DROP DATABASE IF EXISTS $(DB_NAME);" && \
		$(DOCKER_COMPOSE) exec db psql -U $(DB_USER) -d postgres -c "CREATE DATABASE $(DB_NAME);" ; \
	else \
		echo "Cancelled."; \
	fi

# ----------------------------------------------------------------------
# Apply schema.sql into the running DB
# ----------------------------------------------------------------------
db-apply-schema:
	@echo "📦 Applying schema from $(SCHEMA_FILE)"
	cat $(SCHEMA_FILE) | $(DOCKER_COMPOSE) exec -T db psql -U $(DB_USER) -d $(DB_NAME)

# ----------------------------------------------------------------------
# Apply sports teams schema
# ----------------------------------------------------------------------
db-apply-sports-teams-schema:
	@echo "📦 Applying sports teams schema"
	cat services/db/schema_sports_teams.sql | $(DOCKER_COMPOSE) exec -T db psql -U $(DB_USER) -d $(DB_NAME)

# ----------------------------------------------------------------------
# Apply sports teams venue codes schema
# ----------------------------------------------------------------------
db-apply-venue-codes-schema:
	@echo "📦 Applying sports teams venue codes schema"
	cat services/db/schema_sports_teams_venue_codes.sql | $(DOCKER_COMPOSE) exec -T db psql -U $(DB_USER) -d $(DB_NAME)

# ----------------------------------------------------------------------
# Seed sports teams data
# ----------------------------------------------------------------------
db-seed-sports-teams:
	@echo "🌱 Seeding sports teams data"
	cd apps/python-etl && python -m etl.seed_sports_teams

# ----------------------------------------------------------------------
# Quickly open a psql shell inside the DB container
# ----------------------------------------------------------------------
db-shell:
	$(DOCKER_COMPOSE) exec db psql -U $(DB_USER) -d $(DB_NAME)

# ----------------------------------------------------------------------
# Nuke the volume entirely (slow, but guarantees a clean slate)
# ----------------------------------------------------------------------
db-nuke:
	@echo "🔴 HARD RESET: This will NUKE the entire Postgres volume!!"
	@read -p "Continue? (y/N) " confirm && if [ "$$confirm" = "y" ]; then \
		$(DOCKER_COMPOSE) down -v ; \
	else \
		echo "Cancelled."; \
	fi