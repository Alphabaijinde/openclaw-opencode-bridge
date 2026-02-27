#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  install-openclaw-addon.sh /path/to/openclaw [--opencode-bin /path/to/opencode] [--bridge-context /path/to/openclaw-opencode-bridge] [--opencode-mode docker|local] [--non-interactive] [--auto-install] [--yes]

What it does:
  0) Checks local environment prerequisites
  1) Prepares a Docker-native opencode build by default (no host opencode install required)
  2) Optionally supports local opencode binary mode when explicitly requested
  3) Clones OpenClaw repo if target path does not exist
  4) Installs docker add-on files into OpenClaw repo
  5) Upserts required OpenClaw .env keys with safe defaults
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADDON_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BRIDGE_ROOT="$(cd "${ADDON_DIR}/../.." && pwd)"

OPENCLAW_DIR=""
if command -v opencode >/dev/null 2>&1; then
  OPENCODE_BIN_DEFAULT="$(command -v opencode)"
else
  OPENCODE_BIN_DEFAULT="${HOME}/.opencode/bin/opencode"
fi
OPENCODE_BIN="${OPENCODE_BINARY_PATH:-${OPENCODE_BIN_DEFAULT}}"
BRIDGE_CONTEXT="${OPENCODE_BRIDGE_CONTEXT:-${BRIDGE_ROOT}}"
OPENCLAW_REPO_URL="https://github.com/openclaw/openclaw.git"
NON_INTERACTIVE=0
AUTO_INSTALL=0
ASSUME_YES=0
OPENCODE_MODE="${OPENCODE_MODE:-docker}"

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
    --opencode-mode)
      [[ $# -ge 2 ]] || { echo "Missing value for --opencode-mode" >&2; exit 1; }
      OPENCODE_MODE="$2"
      shift 2
      ;;
    --non-interactive)
      NON_INTERACTIVE=1
      shift
      ;;
    --auto-install)
      AUTO_INSTALL=1
      shift
      ;;
    --yes)
      ASSUME_YES=1
      shift
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

if [[ "${OPENCODE_MODE}" == "prebuilt" ]]; then
  OPENCODE_MODE="docker"
fi

if [[ "${OPENCODE_MODE}" != "docker" && "${OPENCODE_MODE}" != "local" ]]; then
  echo "Invalid --opencode-mode: ${OPENCODE_MODE} (expected docker|local)" >&2
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

prompt_with_default() {
  local label="$1"
  local current="$2"
  local input
  read -r -p "${label} [${current}]: " input
  if [[ -z "${input}" ]]; then
    printf "%s" "${current}"
  else
    printf "%s" "${input}"
  fi
}

if [[ -x "${SCRIPT_DIR}/check-environment.sh" ]]; then
  check_args=("${OPENCLAW_DIR}")
  if [[ "${AUTO_INSTALL}" -eq 1 ]]; then
    check_args+=("--auto-install")
  fi
  if [[ "${ASSUME_YES}" -eq 1 ]]; then
    check_args+=("--yes")
  fi
  if [[ "${OPENCODE_MODE}" == "local" ]]; then
    check_args+=("--require-opencode-binary")
  fi
  "${SCRIPT_DIR}/check-environment.sh" "${check_args[@]}" || exit 1
fi

if [[ ! -d "${OPENCLAW_DIR}" ]]; then
  git clone "${OPENCLAW_REPO_URL}" "${OPENCLAW_DIR}"
fi

if [[ ! -f "${OPENCLAW_DIR}/docker-compose.yml" ]]; then
  echo "OpenClaw repo not found (missing docker-compose.yml): ${OPENCLAW_DIR}" >&2
  exit 1
fi

if [[ "${OPENCODE_MODE}" == "local" ]]; then
  if [[ ! -x "${OPENCODE_BIN}" ]]; then
    echo "opencode binary not found or not executable: ${OPENCODE_BIN}" >&2
    echo "Tip: install opencode first, or pass --opencode-bin /absolute/path/to/opencode" >&2
    exit 1
  fi
fi

ENV_FILE="${OPENCLAW_DIR}/.env"
if [[ ! -f "${ENV_FILE}" ]]; then
  if [[ -f "${OPENCLAW_DIR}/.env.example" ]]; then
    cp "${OPENCLAW_DIR}/.env.example" "${ENV_FILE}"
  else
    touch "${ENV_FILE}"
  fi
fi

install -m 0644 "${ADDON_DIR}/docker-compose.override.yml" "${OPENCLAW_DIR}/docker-compose.override.yml"
mkdir -p "${OPENCLAW_DIR}/docker/opencode"
cp -a "${ADDON_DIR}/docker/opencode/." "${OPENCLAW_DIR}/docker/opencode/"
mkdir -p "${OPENCLAW_DIR}/docker/opencode-prebuilt"
cp -a "${ADDON_DIR}/docker/opencode-prebuilt/." "${OPENCLAW_DIR}/docker/opencode-prebuilt/"

if [[ "${OPENCODE_MODE}" == "local" ]]; then
  prepare_binary
fi

set_env_default "${ENV_FILE}" "OPENCODE_AUTH_USERNAME" "opencode"
set_env_default "${ENV_FILE}" "OPENCODE_AUTH_PASSWORD" "$(random_hex)"
set_env_default "${ENV_FILE}" "OPENCODE_INSTALL_DIR" "${HOME}/.opencode"
set_env_default "${ENV_FILE}" "OPENCODE_IMAGE" "openclaw-opencode-local:latest"
set_env_default "${ENV_FILE}" "OPENCODE_PULL_POLICY" "never"
set_env_default "${ENV_FILE}" "OPENCODE_BUILD_CONTEXT" "./docker/opencode-prebuilt"
set_env_default "${ENV_FILE}" "OPENCODE_BUILD_DOCKERFILE" "Dockerfile"
set_env_default "${ENV_FILE}" "OPENCODE_NPM_VERSION" "1.1.51"
set_env_default "${ENV_FILE}" "OPENCODE_BRIDGE_API_KEY" "$(random_hex)"
set_env_default "${ENV_FILE}" "OPENCODE_BRIDGE_PORT" "8787"
set_env_default "${ENV_FILE}" "OPENCLAW_PORT_BIND_HOST" "127.0.0.1"
set_env_default "${ENV_FILE}" "OPENCODE_BRIDGE_CONTEXT" "${BRIDGE_CONTEXT}"
set_env_default "${ENV_FILE}" "OPENCODE_BRIDGE_IMAGE" "ghcr.io/alphabaijinde/openclaw-opencode-bridge:latest"
set_env_default "${ENV_FILE}" "OPENCODE_BRIDGE_PULL_POLICY" "missing"
set_env_default "${ENV_FILE}" "OPENCODE_OPENAI_MODEL_ID" "opencode-local"
set_env_default "${ENV_FILE}" "OPENCODE_DIRECTORY" "/workspace"
set_env_default "${ENV_FILE}" "OPENCODE_PROVIDER_ID" "opencode"
set_env_default "${ENV_FILE}" "OPENCODE_MODEL_ID" "minimax-m2.5-free"
set_env_default "${ENV_FILE}" "HOST_HTTP_PROXY" ""
set_env_default "${ENV_FILE}" "HOST_HTTPS_PROXY" ""
set_env_default "${ENV_FILE}" "HOST_NO_PROXY" "localhost,127.0.0.1,opencode,opencode-bridge,host.docker.internal"
set_env_default "${ENV_FILE}" "FEISHU_APP_ID" ""
set_env_default "${ENV_FILE}" "FEISHU_APP_SECRET" ""
set_env_default "${ENV_FILE}" "FEISHU_VERIFICATION_TOKEN" ""
set_env_default "${ENV_FILE}" "FEISHU_ENCRYPT_KEY" ""

if [[ "${OPENCODE_MODE}" == "local" ]]; then
  upsert_env "${ENV_FILE}" "OPENCODE_BUILD_CONTEXT" "./docker/opencode"
  upsert_env "${ENV_FILE}" "OPENCODE_BUILD_DOCKERFILE" "Dockerfile"
else
  upsert_env "${ENV_FILE}" "OPENCODE_BUILD_CONTEXT" "./docker/opencode-prebuilt"
  upsert_env "${ENV_FILE}" "OPENCODE_BUILD_DOCKERFILE" "Dockerfile"
fi

if [[ "${NON_INTERACTIVE}" -eq 0 && -t 0 ]]; then
  current_provider="$(grep -E '^OPENCODE_PROVIDER_ID=' "${ENV_FILE}" | tail -n1 | cut -d= -f2- || true)"
  current_model="$(grep -E '^OPENCODE_MODEL_ID=' "${ENV_FILE}" | tail -n1 | cut -d= -f2- || true)"
  current_provider="${current_provider:-opencode}"
  current_model="${current_model:-minimax-m2.5-free}"

  echo
  echo "Choose default opencode model mapping for OpenClaw:"
  provider_choice="$(prompt_with_default "OPENCODE_PROVIDER_ID" "${current_provider}")"
  model_choice="$(prompt_with_default "OPENCODE_MODEL_ID" "${current_model}")"
  upsert_env "${ENV_FILE}" "OPENCODE_PROVIDER_ID" "${provider_choice}"
  upsert_env "${ENV_FILE}" "OPENCODE_MODEL_ID" "${model_choice}"
fi

cat <<EOF
Install complete.

OpenClaw repo: ${OPENCLAW_DIR}
Bridge context: ${BRIDGE_CONTEXT}
Opencode mode: ${OPENCODE_MODE}
Opencode binary: ${OPENCODE_BIN}

Next:
  cd ${OPENCLAW_DIR}
EOF

cat <<EOF
  docker compose pull openclaw-gateway opencode-bridge
  docker compose up -d --build
  docker compose exec opencode opencode auth login
  ${ADDON_DIR}/scripts/select-opencode-model.sh ${OPENCLAW_DIR}
EOF
