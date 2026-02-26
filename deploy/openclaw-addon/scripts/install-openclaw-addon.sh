#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  install-openclaw-addon.sh /path/to/openclaw [--opencode-bin /path/to/opencode] [--bridge-context /path/to/openclaw-opencode-bridge]

What it does:
  1) Prepares local opencode binary for Docker build context
  2) Installs docker add-on files into OpenClaw repo
  3) Upserts required OpenClaw .env keys with safe defaults
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADDON_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BRIDGE_ROOT="$(cd "${ADDON_DIR}/../.." && pwd)"

OPENCLAW_DIR=""
OPENCODE_BIN="${OPENCODE_BINARY_PATH:-${HOME}/.opencode/bin/opencode}"
BRIDGE_CONTEXT="${OPENCODE_BRIDGE_CONTEXT:-${BRIDGE_ROOT}}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --opencode-bin)
      [[ $# -ge 2 ]] || { echo "Missing value for --opencode-bin" >&2; exit 1; }
      OPENCODE_BIN="$2"
      shift 2
      ;;
    --bridge-context)
      [[ $# -ge 2 ]] || { echo "Missing value for --bridge-context" >&2; exit 1; }
      BRIDGE_CONTEXT="$2"
      shift 2
      ;;
    *)
      if [[ -z "${OPENCLAW_DIR}" ]]; then
        OPENCLAW_DIR="$1"
        shift
      else
        echo "Unexpected argument: $1" >&2
        usage
        exit 1
      fi
      ;;
  esac
done

if [[ -z "${OPENCLAW_DIR}" ]]; then
  usage
  exit 1
fi

if [[ ! -f "${OPENCLAW_DIR}/docker-compose.yml" ]]; then
  echo "OpenClaw repo not found (missing docker-compose.yml): ${OPENCLAW_DIR}" >&2
  exit 1
fi

if [[ ! -x "${OPENCODE_BIN}" ]]; then
  echo "opencode binary not found or not executable: ${OPENCODE_BIN}" >&2
  echo "Tip: install opencode first, or pass --opencode-bin /absolute/path/to/opencode" >&2
  exit 1
fi

prepare_binary() {
  "${SCRIPT_DIR}/prepare-opencode-binary.sh" "${OPENCODE_BIN}"
}

random_hex() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 24
  else
    # 48 hex chars
    head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n'
  fi
}

upsert_env() {
  local file="$1"
  local key="$2"
  local value="$3"
  local escaped="${value//&/\\&}"
  if grep -qE "^${key}=" "${file}"; then
    sed -i "s|^${key}=.*$|${key}=${escaped}|" "${file}"
  else
    printf "%s=%s\n" "${key}" "${value}" >> "${file}"
  fi
}

set_env_default() {
  local file="$1"
  local key="$2"
  local value="$3"
  local current
  current="$(grep -E "^${key}=" "${file}" | tail -n1 | cut -d= -f2- || true)"
  if [[ -z "${current}" ]]; then
    upsert_env "${file}" "${key}" "${value}"
  fi
}

ENV_FILE="${OPENCLAW_DIR}/.env"
if [[ ! -f "${ENV_FILE}" ]]; then
  if [[ -f "${OPENCLAW_DIR}/.env.example" ]]; then
    cp "${OPENCLAW_DIR}/.env.example" "${ENV_FILE}"
  else
    touch "${ENV_FILE}"
  fi
fi

prepare_binary

install -m 0644 "${ADDON_DIR}/docker-compose.override.yml" "${OPENCLAW_DIR}/docker-compose.override.yml"
mkdir -p "${OPENCLAW_DIR}/docker/opencode"
cp -a "${ADDON_DIR}/docker/opencode/." "${OPENCLAW_DIR}/docker/opencode/"

set_env_default "${ENV_FILE}" "OPENCODE_AUTH_USERNAME" "opencode"
set_env_default "${ENV_FILE}" "OPENCODE_AUTH_PASSWORD" "$(random_hex)"
set_env_default "${ENV_FILE}" "OPENCODE_INSTALL_DIR" "${HOME}/.opencode"
set_env_default "${ENV_FILE}" "OPENCODE_BRIDGE_API_KEY" "$(random_hex)"
set_env_default "${ENV_FILE}" "OPENCODE_BRIDGE_PORT" "8787"
set_env_default "${ENV_FILE}" "OPENCODE_BRIDGE_CONTEXT" "${BRIDGE_CONTEXT}"
set_env_default "${ENV_FILE}" "OPENCODE_OPENAI_MODEL_ID" "opencode-local"
set_env_default "${ENV_FILE}" "OPENCODE_DIRECTORY" "/workspace"
set_env_default "${ENV_FILE}" "FEISHU_APP_ID" ""
set_env_default "${ENV_FILE}" "FEISHU_APP_SECRET" ""
set_env_default "${ENV_FILE}" "FEISHU_VERIFICATION_TOKEN" ""
set_env_default "${ENV_FILE}" "FEISHU_ENCRYPT_KEY" ""

cat <<EOF
Install complete.

OpenClaw repo: ${OPENCLAW_DIR}
Bridge context: ${BRIDGE_CONTEXT}
Opencode binary: ${OPENCODE_BIN}

Next:
  cd ${OPENCLAW_DIR}
  docker compose build opencode opencode-bridge
  docker compose up -d
  docker compose exec opencode opencode auth login
  docker compose exec opencode opencode models
EOF
