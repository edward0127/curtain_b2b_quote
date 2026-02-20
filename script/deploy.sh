#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
APP_SERVICE="${APP_SERVICE:-web}"

# Defaults: safe for "always works" deployments
GIT_PULL="${GIT_PULL:-0}"                  # 1 to run git pull
RUN_MIGRATIONS="${RUN_MIGRATIONS:-1}"      # 1 to run db:prepare
HEALTHCHECK_URL="${HEALTHCHECK_URL:-}"     # e.g. https://curtain.tudouke.com
CONTAINER_NAME="${CONTAINER_NAME:-curtain_b2b_quote}"  # matches your compose container_name

usage() {
  cat <<'EOF'
Usage:
  script/deploy.sh deploy       # pull image, migrate (optional), down+up, verify
  script/deploy.sh restart      # down+up only, verify
  script/deploy.sh migrate      # run db:prepare only
  script/deploy.sh pull         # pull image only
  script/deploy.sh logs         # tail app logs
  script/deploy.sh status       # show compose status + image IDs
  script/deploy.sh down         # stop stack (no volumes removed)
  script/deploy.sh verify       # verify running container uses latest pulled image

Environment overrides:
  COMPOSE_FILE=docker-compose.yml
  APP_SERVICE=web
  CONTAINER_NAME=curtain_b2b_quote

  GIT_PULL=1                    # run git pull before deploy
  RUN_MIGRATIONS=0              # skip db:prepare
  HEALTHCHECK_URL=https://curtain.tudouke.com
EOF
}

ensure_prerequisites() {
  if [[ ! -f "$COMPOSE_FILE" ]]; then
    echo "ERROR: compose file not found: $COMPOSE_FILE"
    exit 1
  fi

  if [[ ! -f ".env.prod" ]]; then
    echo "ERROR: .env.prod not found (expected in repo root)."
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

maybe_git_pull() {
  if [[ "$GIT_PULL" == "1" ]]; then
    echo "== git pull =="
    git pull
  fi
}

pull_image() {
  echo "== docker compose pull $APP_SERVICE =="
  compose pull "$APP_SERVICE"
}

migrate() {
  echo "== db:prepare =="
  compose run --rm --no-deps "$APP_SERVICE" bin/rails db:prepare
}

restart_stack() {
  echo "== docker compose down (remove orphans) =="
  compose down --remove-orphans

  echo "== docker compose up -d $APP_SERVICE =="
  compose up -d "$APP_SERVICE"
}

service_image_ref() {
  # Extract the image reference for APP_SERVICE from `docker compose config`
  # Works for typical compose output formatting.
  compose config | awk -v svc="$APP_SERVICE" '
    $0 ~ "^  "svc":$" {in_svc=1; next}
    in_svc && $0 ~ "^    image:" {sub("^    image:[[:space:]]*", "", $0); print $0; exit}
    in_svc && $0 ~ "^  [A-Za-z0-9_-]+:$" {in_svc=0}
  '
}

image_id_for_ref() {
  local img_ref="$1"
  docker image inspect "$img_ref" --format '{{.Id}}'
}

container_image_id() {
  # Prefer fixed container_name; fall back to compose ps if needed.
  if docker inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
    docker inspect "$CONTAINER_NAME" --format '{{.Image}}'
    return 0
  fi

  local cid
  cid="$(compose ps -q "$APP_SERVICE" | head -n 1)"
  if [[ -z "${cid:-}" ]]; then
    echo ""
    return 0
  fi
  docker inspect "$cid" --format '{{.Image}}'
}

verify() {
  local img_ref
  img_ref="$(service_image_ref || true)"

  if [[ -z "${img_ref:-}" ]]; then
    echo "WARN: could not detect image reference from compose config."
    echo "      Make sure your service has an 'image:' field."
    return 0
  fi

  local wanted_id running_id
  wanted_id="$(image_id_for_ref "$img_ref")"
  running_id="$(container_image_id)"

  echo "== verify image =="
  echo "compose image ref: $img_ref"
  echo "pulled image id : $wanted_id"
  echo "running image id: $running_id"

  if [[ -z "${running_id:-}" ]]; then
    echo "WARN: app container not found (is it running?)"
    return 1
  fi

  if [[ "$wanted_id" != "$running_id" ]]; then
    echo "ERROR: running container is not using the latest pulled image."
    echo "Tip: run: script/deploy.sh restart"
    return 1
  fi

  echo "OK: running container matches pulled image."
}

healthcheck() {
  if [[ -z "${HEALTHCHECK_URL:-}" ]]; then
    return 0
  fi

  echo "== healthcheck =="
  echo "GET/HEAD: $HEALTHCHECK_URL"
  # HEAD request first; fall back to GET if needed
  if command -v curl >/dev/null 2>&1; then
    curl -fsS -I "$HEALTHCHECK_URL" >/dev/null || curl -fsS "$HEALTHCHECK_URL" >/dev/null
    echo "OK: healthcheck passed."
  else
    echo "WARN: curl not installed, skipping healthcheck."
  fi
}

status() {
  compose ps
  verify || true
}

command="${1:-deploy}"
ensure_prerequisites

case "$command" in
  deploy)
    maybe_git_pull
    pull_image
    if [[ "$RUN_MIGRATIONS" == "1" ]]; then
      migrate
    fi
    restart_stack
    verify
    healthcheck
    ;;
  restart)
    restart_stack
    verify
    healthcheck
    ;;
  migrate)
    migrate
    ;;
  pull)
    pull_image
    ;;
  verify)
    verify
    ;;
  logs)
    compose logs -f --tail=200 "$APP_SERVICE"
    ;;
  status)
    status
    ;;
  down)
    compose down --remove-orphans
    ;;
  *)
    usage
    exit 1
    ;;
esac