#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  select-opencode-model.sh /path/to/openclaw

Requirement:
  - opencode container is running
  - you already completed: docker compose exec opencode opencode auth login
EOF
}

OPENCLAW_DIR="${1:-}"
if [[ -z "${OPENCLAW_DIR}" || "${OPENCLAW_DIR}" == "-h" || "${OPENCLAW_DIR}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ ! -f "${OPENCLAW_DIR}/docker-compose.yml" ]]; then
  echo "OpenClaw repo not found: ${OPENCLAW_DIR}" >&2
  exit 1
fi

ENV_FILE="${OPENCLAW_DIR}/.env"
if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing .env file: ${ENV_FILE}" >&2
  exit 1
fi

dc() {
  docker compose -f "${OPENCLAW_DIR}/docker-compose.yml" -f "${OPENCLAW_DIR}/docker-compose.override.yml" "$@"
}

if ! dc ps opencode >/dev/null 2>&1; then
  echo "Cannot access docker compose in ${OPENCLAW_DIR}" >&2
  exit 1
fi

mapfile -t MODELS < <(
  dc exec -T opencode opencode models 2>/dev/null \
    | grep -E '^[A-Za-z0-9._-]+/.+$' || true
)

if [[ "${#MODELS[@]}" -eq 0 ]]; then
  echo "No models returned." >&2
  echo "Run these first:" >&2
  echo "  cd ${OPENCLAW_DIR}" >&2
  echo "  docker compose exec opencode opencode auth login" >&2
  echo "  docker compose exec opencode opencode models" >&2
  exit 1
fi

recommend_index=1
for i in "${!MODELS[@]}"; do
  if [[ "${MODELS[$i]}" == *"-free"* ]]; then
    recommend_index=$((i + 1))
    break
  fi
done

echo "Available opencode models:"
for i in "${!MODELS[@]}"; do
  n=$((i + 1))
  mark=""
  if [[ "${n}" -eq "${recommend_index}" ]]; then
    mark=" (recommended)"
  fi
  echo "  ${n}) ${MODELS[$i]}${mark}"
done

pick=""
if ! read -r -p "Choose model [${recommend_index}]: " pick; then
  pick="${recommend_index}"
fi
pick="${pick:-${recommend_index}}"
if ! [[ "${pick}" =~ ^[0-9]+$ ]] || [[ "${pick}" -lt 1 ]] || [[ "${pick}" -gt "${#MODELS[@]}" ]]; then
  echo "Invalid selection: ${pick}" >&2
  exit 1
fi

chosen="${MODELS[$((pick - 1))]}"
provider="${chosen%%/*}"
model="${chosen#*/}"

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

upsert_env "${ENV_FILE}" "OPENCODE_PROVIDER_ID" "${provider}"
upsert_env "${ENV_FILE}" "OPENCODE_MODEL_ID" "${model}"

echo "Selected:"
echo "  OPENCODE_PROVIDER_ID=${provider}"
echo "  OPENCODE_MODEL_ID=${model}"
echo
echo "Apply with:"
echo "  cd ${OPENCLAW_DIR}"
echo "  docker compose restart opencode-bridge"
