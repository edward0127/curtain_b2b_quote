#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
APP_SERVICE="${APP_SERVICE:-web}"

usage() {
  cat <<'EOF'
Usage:
  script/deploy.sh bootstrap   # First deploy: pull, migrate, seed, up
  script/deploy.sh deploy      # Update deploy: pull, migrate, up
  script/deploy.sh migrate     # Run db:prepare
  script/deploy.sh logs        # Tail app logs
  script/deploy.sh status      # Show compose status
  script/deploy.sh down        # Stop app stack
  script/deploy.sh pull        # Pull latest image

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

pull() {
  set +e
  compose pull "$APP_SERVICE"
  status=$?
  set -e

  if [[ $status -ne 0 ]]; then
    cat <<'EOF'
ERROR: docker compose pull failed.

If your GHCR image is private, you must login on the server first, e.g.
  echo "$GHCR_TOKEN" | docker login ghcr.io -u <your_github_username> --password-stdin

Then re-run:
  script/deploy.sh deploy
EOF
    exit $status
  fi
}

migrate() {
  # --no-deps avoids starting other services during one-off tasks
  compose run --rm --no-deps "$APP_SERVICE" bin/rails db:prepare
}

seed() {
  compose run --rm --no-deps "$APP_SERVICE" bin/rails db:seed
}

up() {
  compose up -d "$APP_SERVICE"
}

command="${1:-deploy}"
ensure_prerequisites

case "$command" in
  bootstrap)
    pull
    migrate
    seed
    up
    ;;
  deploy)
    pull
    migrate
    up
    ;;
  pull)
    pull
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