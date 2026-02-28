#!/usr/bin/env bash
set -euo pipefail

IMAGE="${IMAGE:-ghcr.io/alphabaijinde/openclaw-opencode-bridge:latest}"
CONTAINER_NAME="${CONTAINER_NAME:-openclaw-opencode-all-in-one}"
APP_HOME="${APP_HOME:-${HOME}/.openclaw-opencode-all-in-one}"
DATA_DIR="${DATA_DIR:-${APP_HOME}/data}"
OPENCLAW_GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
OPENCLAW_BRIDGE_PORT="${OPENCLAW_BRIDGE_PORT:-18790}"
OPENCODE_BRIDGE_PORT="${OPENCODE_BRIDGE_PORT:-8787}"
HOST_HTTP_PROXY="${HOST_HTTP_PROXY:-${HTTP_PROXY:-}}"
HOST_HTTPS_PROXY="${HOST_HTTPS_PROXY:-${HTTPS_PROXY:-}}"
HOST_NO_PROXY="${HOST_NO_PROXY:-localhost,127.0.0.1,host.docker.internal}"
HOST_AUTOMATION_BASE_URL="${HOST_AUTOMATION_BASE_URL:-http://host.docker.internal:4567}"
AUTO_OPEN_DASHBOARD="${AUTO_OPEN_DASHBOARD:-1}"
RUN_OPENCODE_LOGIN=0
DOCKER_BIN=""

normalize_docker_host() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    local desktop_sock="${HOME}/.docker/run/docker.sock"
    if [[ -S "${desktop_sock}" ]]; then
      export DOCKER_HOST="unix://${desktop_sock}"
      return
    fi
  fi
}

resolve_docker_bin() {
  case "$(uname -s)" in
    Darwin)
      if [[ -x "${HOME}/Applications/Docker.app/Contents/Resources/bin/docker" ]]; then
        DOCKER_BIN="${HOME}/Applications/Docker.app/Contents/Resources/bin/docker"
        return
      fi
      if [[ -x "/Applications/Docker.app/Contents/Resources/bin/docker" ]]; then
        DOCKER_BIN="/Applications/Docker.app/Contents/Resources/bin/docker"
        return
      fi
      ;;
  esac

  if command -v docker >/dev/null 2>&1; then
    DOCKER_BIN="$(command -v docker)"
    return
  fi

  DOCKER_BIN=""
}

usage() {
  cat <<'EOF'
Usage:
  scripts/install-all-in-one.sh [--opencode-login] [--skip-opencode-login]

Flags:
  --opencode-login       Start interactive opencode login after install
  --skip-opencode-login  Compatibility flag; install already skips login by default

Environment overrides:
  IMAGE=ghcr.io/alphabaijinde/openclaw-opencode-bridge:latest
  CONTAINER_NAME=openclaw-opencode-all-in-one
  APP_HOME=$HOME/.openclaw-opencode-all-in-one
  HOST_HTTP_PROXY=http://host:port
  HOST_HTTPS_PROXY=http://host:port
  HOST_NO_PROXY=localhost,127.0.0.1,host.docker.internal
  HOST_AUTOMATION_BASE_URL=http://host.docker.internal:4567
  AUTO_OPEN_DASHBOARD=1
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --opencode-login)
      RUN_OPENCODE_LOGIN=1
      shift
      ;;
    --skip-opencode-login)
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

run_privileged() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    return 1
  fi
}

ensure_docker() {
  normalize_docker_host
  resolve_docker_bin
  if [[ -n "${DOCKER_BIN}" ]]; then
    return 0
  fi

  case "$(uname -s)" in
    Darwin)
      command -v brew >/dev/null 2>&1 || {
        echo "Homebrew is required to auto-install Docker Desktop on macOS." >&2
        exit 1
      }
      brew install --cask docker-desktop || brew install --cask docker
      ;;
    Linux)
      if command -v apt-get >/dev/null 2>&1; then
        run_privileged apt-get update
        run_privileged apt-get install -y docker.io docker-compose-plugin
        if command -v systemctl >/dev/null 2>&1; then
          run_privileged systemctl enable --now docker || true
        fi
      else
        echo "Docker is not installed and this installer only auto-installs on macOS/Homebrew or Debian/Ubuntu." >&2
        exit 1
      fi
      ;;
    *)
      echo "Unsupported OS for Docker auto-install: $(uname -s)" >&2
      exit 1
      ;;
  esac

  resolve_docker_bin
  if [[ -z "${DOCKER_BIN}" ]]; then
    echo "Docker CLI is still unavailable after installation." >&2
    exit 1
  fi
}

wait_for_docker() {
  normalize_docker_host
  resolve_docker_bin
  local tries=90
  local i

  case "$(uname -s)" in
    Darwin)
      if command -v open >/dev/null 2>&1; then
        open -a Docker >/dev/null 2>&1 || true
      fi
      ;;
  esac

  for ((i = 0; i < tries; i += 1)); do
    if "${DOCKER_BIN}" context ls >/dev/null 2>&1 && "${DOCKER_BIN}" context ls | grep -q 'desktop-linux'; then
      "${DOCKER_BIN}" context use desktop-linux >/dev/null 2>&1 || true
    fi
    if "${DOCKER_BIN}" info >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done

  echo "Docker daemon did not become ready in time." >&2
  exit 1
}

wait_for_http() {
  local url="$1"
  local tries="${2:-60}"
  local i
  for ((i = 0; i < tries; i += 1)); do
    if curl -fsS "${url}" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  return 1
}

open_url() {
  local target="$1"
  case "$(uname -s)" in
    Darwin)
      if command -v open >/dev/null 2>&1; then
        open "${target}" >/dev/null 2>&1 || true
      fi
      ;;
    Linux)
      if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "${target}" >/dev/null 2>&1 || true
      fi
      ;;
  esac
}

ensure_docker
wait_for_docker

mkdir -p "${DATA_DIR}"

if ! "${DOCKER_BIN}" image inspect "${IMAGE}" >/dev/null 2>&1; then
  "${DOCKER_BIN}" pull "${IMAGE}"
fi
"${DOCKER_BIN}" rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true

docker_args=(
  run -d
  --name "${CONTAINER_NAME}"
  --restart unless-stopped
  -p "${OPENCLAW_GATEWAY_PORT}:18789"
  -p "${OPENCLAW_BRIDGE_PORT}:18790"
  -p "${OPENCODE_BRIDGE_PORT}:8787"
  -v "${DATA_DIR}:/var/lib/openclaw-opencode"
)

if [[ -n "${HOST_HTTP_PROXY}" ]]; then
  docker_args+=(-e "HOST_HTTP_PROXY=${HOST_HTTP_PROXY}")
fi
if [[ -n "${HOST_HTTPS_PROXY}" ]]; then
  docker_args+=(-e "HOST_HTTPS_PROXY=${HOST_HTTPS_PROXY}")
fi
if [[ -n "${HOST_NO_PROXY}" ]]; then
  docker_args+=(-e "HOST_NO_PROXY=${HOST_NO_PROXY}")
fi
if [[ -n "${HOST_AUTOMATION_BASE_URL}" ]]; then
  docker_args+=(-e "HOST_AUTOMATION_BASE_URL=${HOST_AUTOMATION_BASE_URL}")
fi

"${DOCKER_BIN}" "${docker_args[@]}" "${IMAGE}"

wait_for_http "http://127.0.0.1:${OPENCODE_BRIDGE_PORT}/health" 90 || {
  echo "Bridge health check failed. Recent logs:" >&2
  "${DOCKER_BIN}" logs --tail 100 "${CONTAINER_NAME}" >&2 || true
  exit 1
}

if [[ -f "${DATA_DIR}/runtime.env" ]]; then
  # shellcheck disable=SC1090
  source "${DATA_DIR}/runtime.env"
fi

echo
echo "Installed successfully."
echo "Dashboard: http://127.0.0.1:${OPENCLAW_GATEWAY_PORT}"
if [[ -n "${RUNTIME_OPENCLAW_GATEWAY_TOKEN:-}" ]]; then
  DASHBOARD_DIRECT_URL="http://127.0.0.1:${OPENCLAW_GATEWAY_PORT}/#token=${RUNTIME_OPENCLAW_GATEWAY_TOKEN}"
  echo "Dashboard (direct): ${DASHBOARD_DIRECT_URL}"
fi
echo "Bridge: http://127.0.0.1:${OPENCODE_BRIDGE_PORT}/v1"
echo "Data dir: ${DATA_DIR}"
if [[ -n "${RUNTIME_OPENCLAW_GATEWAY_TOKEN:-}" ]]; then
  echo "OpenClaw token: ${RUNTIME_OPENCLAW_GATEWAY_TOKEN}"
fi
if [[ -n "${RUNTIME_BRIDGE_API_KEY:-}" ]]; then
  echo "Bridge API key: ${RUNTIME_BRIDGE_API_KEY}"
fi
echo "Host automation base URL (optional): ${HOST_AUTOMATION_BASE_URL}"
echo "Start host read-only agent: ./scripts/start-host-automation-agent.sh"

if [[ -n "${DASHBOARD_DIRECT_URL:-}" && "${AUTO_OPEN_DASHBOARD}" != "0" && -t 1 ]]; then
  echo "Opening dashboard in your default browser..."
  open_url "${DASHBOARD_DIRECT_URL}"
fi

if [[ "${RUN_OPENCODE_LOGIN}" -eq 1 && -t 0 && -t 1 ]]; then
  echo
  echo "Starting opencode login flow..."
  "${DOCKER_BIN}" exec -it "${CONTAINER_NAME}" opencode auth login || true
else
  echo
  echo "Optional: run this if you want to log in to your own opencode account/providers:"
  echo "  ${DOCKER_BIN} exec -it ${CONTAINER_NAME} opencode auth login"
fi
