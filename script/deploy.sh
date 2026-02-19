#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
APP_SERVICE="${APP_SERVICE:-web}"

usage() {
  cat <<'EOF'
Usage:
  script/deploy.sh bootstrap   # First deploy: build, migrate, seed, up
  script/deploy.sh deploy      # Update deploy: build, migrate, up
  script/deploy.sh migrate     # Run db:prepare
  script/deploy.sh logs        # Tail app logs
  script/deploy.sh status      # Show compose status
  script/deploy.sh down        # Stop app stack

Environment overrides:
  COMPOSE_FILE=docker-compose.yml
  APP_SERVICE=web
EOF
}

ensure_prerequisites() {
  if [[ ! -f "$COMPOSE_FILE" ]]; then
    echo "ERROR: compose file not found: $COMPOSE_FILE"
    exit 1
  fi

  if [[ ! -f ".env.prod" ]]; then
    echo "ERROR: .env.prod not found. Create it from .env.prod.example first."
    exit 1
  fi

  if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: docker is not installed."
    exit 1
  fi

  if ! docker compose version >/dev/null 2>&1; then
    echo "ERROR: docker compose plugin is required."
    exit 1
  fi
}

compose() {
  docker compose -f "$COMPOSE_FILE" "$@"
}

build() {
  compose build "$APP_SERVICE"
}

migrate() {
  compose run --rm "$APP_SERVICE" bin/rails db:prepare
}

seed() {
  compose run --rm "$APP_SERVICE" bin/rails db:seed
}

up() {
  compose up -d "$APP_SERVICE"
}

command="${1:-deploy}"
ensure_prerequisites

case "$command" in
  bootstrap)
    build
    migrate
    seed
    up
    ;;
  deploy)
    build
    migrate
    up
    ;;
  migrate)
    migrate
    ;;
  logs)
    compose logs -f "$APP_SERVICE"
    ;;
  status)
    compose ps
    ;;
  down)
    compose down
    ;;
  *)
    usage
    exit 1
    ;;
esac
