#!/usr/bin/env bash
set -euo pipefail

SERVER="${SERVER:-root@amituofo.com.au}"
REMOTE_DIR="${REMOTE_DIR:-/var/curtain_b2b_quote}"
IMAGE="${IMAGE:-ghcr.io/edward0127/curtain_b2b_quote}"
PLATFORM="${PLATFORM:-linux/amd64}"
PUSH_GIT="${PUSH_GIT:-true}"
SSH_KEY="${SSH_KEY:-}"
AUTO_COMMIT_MESSAGE=""
SKIP_REMOTE="${SKIP_REMOTE:-false}"

usage() {
  cat <<'EOF'
Usage:
  ./script/deploy_production.sh [options]

Options:
  --auto-commit "message"   Stage all changes and create commit before push/build.
  --no-push-git             Skip git push step.
  --skip-remote             Skip SSH deploy step (build/push image only).
  --server user@host        SSH target (default: root@amituofo.com.au).
  --remote-dir /path        Remote repo path (default: /var/curtain_b2b_quote).
  --image ghcr.io/org/repo  Image repository (default: ghcr.io/edward0127/curtain_b2b_quote).
  --platform linux/amd64    Buildx platform (default: linux/amd64).
  --ssh-key /path/to/key    SSH private key path.
  -h, --help                Show this help.

Examples:
  ./script/deploy_production.sh --auto-commit "Update homepage copy"
  ./script/deploy_production.sh --no-push-git --skip-remote
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --auto-commit)
      [[ $# -lt 2 ]] && { echo "Missing value for --auto-commit" >&2; usage; exit 1; }
      AUTO_COMMIT_MESSAGE="$2"
      shift 2
      ;;
    --no-push-git)
      PUSH_GIT="false"
      shift
      ;;
    --skip-remote)
      SKIP_REMOTE="true"
      shift
      ;;
    --server)
      [[ $# -lt 2 ]] && { echo "Missing value for --server" >&2; usage; exit 1; }
      SERVER="$2"
      shift 2
      ;;
    --remote-dir)
      [[ $# -lt 2 ]] && { echo "Missing value for --remote-dir" >&2; usage; exit 1; }
      REMOTE_DIR="$2"
      shift 2
      ;;
    --image)
      [[ $# -lt 2 ]] && { echo "Missing value for --image" >&2; usage; exit 1; }
      IMAGE="$2"
      shift 2
      ;;
    --platform)
      [[ $# -lt 2 ]] && { echo "Missing value for --platform" >&2; usage; exit 1; }
      PLATFORM="$2"
      shift 2
      ;;
    --ssh-key)
      [[ $# -lt 2 ]] && { echo "Missing value for --ssh-key" >&2; usage; exit 1; }
      SSH_KEY="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_DIR"

for cmd in git docker ssh; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
done

if [[ -n "$AUTO_COMMIT_MESSAGE" ]]; then
  if [[ -n "$(git status --porcelain)" ]]; then
    echo "Creating commit: $AUTO_COMMIT_MESSAGE"
    git add -A
    git commit -m "$AUTO_COMMIT_MESSAGE"
  else
    echo "No local changes detected, skipping auto-commit."
  fi
fi

if [[ -n "$(git status --porcelain)" ]]; then
  cat >&2 <<'EOF'
Working tree is not clean.
Commit or stash changes first, or use:
  ./script/deploy_production.sh --auto-commit "your message"
EOF
  exit 1
fi

if [[ "$PUSH_GIT" == "true" ]]; then
  echo "Pushing current branch..."
  git push
fi

SHA="$(git rev-parse --short HEAD)"
if [[ -z "$SHA" ]]; then
  echo "Could not resolve git short SHA." >&2
  exit 1
fi

echo "Building and pushing images:"
echo "  ${IMAGE}:${SHA}"
echo "  ${IMAGE}:latest"
docker buildx build --platform "$PLATFORM" \
  -t "${IMAGE}:${SHA}" \
  -t "${IMAGE}:latest" \
  --push .

if [[ "$SKIP_REMOTE" == "true" ]]; then
  echo "Skipping remote deployment (--skip-remote)."
  exit 0
fi

SSH_ARGS=()
if [[ -n "$SSH_KEY" ]]; then
  if [[ "$SSH_KEY" =~ ^[A-Za-z]:\\ ]] && command -v cygpath >/dev/null 2>&1; then
    SSH_KEY="$(cygpath -u "$SSH_KEY")"
  fi
  if [[ ! -f "$SSH_KEY" ]]; then
    echo "SSH key not found: $SSH_KEY" >&2
    exit 1
  fi
  SSH_ARGS+=(-i "$SSH_KEY")
fi

SSH_OPTIONS=(-o BatchMode=yes -o PreferredAuthentications=publickey -o PasswordAuthentication=no)

echo "Running remote deploy on ${SERVER}:${REMOTE_DIR}..."
REMOTE_CMD="set -euo pipefail; cd '$REMOTE_DIR'; git pull --ff-only; ./script/deploy.sh deploy"
if ! ssh "${SSH_OPTIONS[@]}" "${SSH_ARGS[@]}" "$SERVER" "$REMOTE_CMD"; then
  echo "Remote deployment failed. Check SSH access and server logs." >&2
  exit 1
fi

echo "Deployment complete."
