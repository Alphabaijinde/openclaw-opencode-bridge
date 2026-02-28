#!/usr/bin/env bash
set -euo pipefail

STACK_DIR="${OPENCLAW_STACK_DIR:-/var/lib/openclaw-opencode}"
OPENCLAW_DATA_DIR="${OPENCLAW_DATA_DIR:-${STACK_DIR}/openclaw}"
OPENCODE_CONFIG_HOME="${OPENCODE_CONFIG_HOME:-${STACK_DIR}/opencode-config}"
OPENCODE_SHARE_HOME="${OPENCODE_SHARE_HOME:-${STACK_DIR}/opencode-share}"
WORKSPACE_DIR="${OPENCODE_DIRECTORY:-${STACK_DIR}/workspace}"
RUNTIME_ENV="${STACK_DIR}/runtime.env"
OPENCLAW_WORKSPACE_DIR="${OPENCLAW_DATA_DIR}/workspace"

OPENCLAW_GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
OPENCLAW_GATEWAY_BIND="${OPENCLAW_GATEWAY_BIND:-lan}"
OPENCLAW_BRIDGE_PORT="${OPENCLAW_BRIDGE_PORT:-18790}"
LOCAL_OPENCODE_PORT="${LOCAL_OPENCODE_PORT:-4096}"
OPENCODE_BRIDGE_PORT="${OPENCODE_BRIDGE_PORT:-8787}"
OPENAI_MODEL_ID="${OPENCODE_OPENAI_MODEL_ID:-opencode-local}"
OPENCODE_PROVIDER_ID="${OPENCODE_PROVIDER_ID:-opencode}"
OPENCODE_MODEL_ID="${OPENCODE_MODEL_ID:-minimax-m2.5-free}"
OPENCODE_AUTH_USERNAME="${OPENCODE_AUTH_USERNAME:-opencode}"
HTTP_PROXY_VALUE="${HOST_HTTP_PROXY:-${HTTP_PROXY:-}}"
HTTPS_PROXY_VALUE="${HOST_HTTPS_PROXY:-${HTTPS_PROXY:-}}"
NO_PROXY_VALUE="${HOST_NO_PROXY:-localhost,127.0.0.1,opencode-bridge,host.docker.internal}"
HOST_AUTOMATION_BASE_URL="${HOST_AUTOMATION_BASE_URL:-http://host.docker.internal:4567}"
OPENCLAW_AUTO_APPROVE_FIRST_DEVICE="${OPENCLAW_AUTO_APPROVE_FIRST_DEVICE:-1}"

mkdir -p "${STACK_DIR}" "${OPENCLAW_DATA_DIR}" "${OPENCLAW_WORKSPACE_DIR}" "${OPENCODE_CONFIG_HOME}" "${OPENCODE_SHARE_HOME}" "${WORKSPACE_DIR}"
mkdir -p "${HOME}/.config" "${HOME}/.local/share"

if [[ -e "${HOME}/.openclaw" && ! -L "${HOME}/.openclaw" ]]; then
  rm -rf "${HOME}/.openclaw"
fi
ln -sfn "${OPENCLAW_DATA_DIR}" "${HOME}/.openclaw"

if [[ -e "${HOME}/.config/opencode" && ! -L "${HOME}/.config/opencode" ]]; then
  rm -rf "${HOME}/.config/opencode"
fi
ln -sfn "${OPENCODE_CONFIG_HOME}" "${HOME}/.config/opencode"

if [[ -e "${HOME}/.local/share/opencode" && ! -L "${HOME}/.local/share/opencode" ]]; then
  rm -rf "${HOME}/.local/share/opencode"
fi
ln -sfn "${OPENCODE_SHARE_HOME}" "${HOME}/.local/share/opencode"

if [[ -f "${RUNTIME_ENV}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${RUNTIME_ENV}"
  set +a
fi

random_hex() {
  node -e "const { randomBytes } = require('node:crypto'); process.stdout.write(randomBytes(24).toString('hex'));"
}

OPENCLAW_GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-${RUNTIME_OPENCLAW_GATEWAY_TOKEN:-$(random_hex)}}"
OPENCODE_AUTH_PASSWORD="${OPENCODE_AUTH_PASSWORD:-${RUNTIME_OPENCODE_AUTH_PASSWORD:-$(random_hex)}}"
BRIDGE_API_KEY="${BRIDGE_API_KEY:-${RUNTIME_BRIDGE_API_KEY:-$(random_hex)}}"

cat > "${RUNTIME_ENV}" <<EOF
RUNTIME_OPENCLAW_GATEWAY_TOKEN=${OPENCLAW_GATEWAY_TOKEN}
RUNTIME_OPENCODE_AUTH_PASSWORD=${OPENCODE_AUTH_PASSWORD}
RUNTIME_BRIDGE_API_KEY=${BRIDGE_API_KEY}
EOF
chmod 600 "${RUNTIME_ENV}"

export HTTP_PROXY="${HTTP_PROXY_VALUE}"
export HTTPS_PROXY="${HTTPS_PROXY_VALUE}"
export NO_PROXY="${NO_PROXY_VALUE}"
export http_proxy="${HTTP_PROXY_VALUE}"
export https_proxy="${HTTPS_PROXY_VALUE}"
export no_proxy="${NO_PROXY_VALUE}"
export OPENCODE_DIRECTORY="${WORKSPACE_DIR}"

seed_host_automation_note() {
  local user_md="${OPENCLAW_WORKSPACE_DIR}/USER.md"
  local marker="Host automation bridge (read-only by default)"
  local tmp_file

  if [[ "${HOST_AUTOMATION_BASE_URL}" == "off" ]]; then
    return 0
  fi

  if [[ -f "${user_md}" ]] && grep -Fq "${marker}" "${user_md}"; then
    return 0
  fi

  tmp_file="$(mktemp)"
  if [[ -f "${user_md}" ]]; then
    cat "${user_md}" > "${tmp_file}"
    printf '\n\n' >> "${tmp_file}"
  fi

  cat >> "${tmp_file}" <<EOF
${marker}
- Optional host inspection API: ${HOST_AUTOMATION_BASE_URL}
- Use GET requests only unless the operator explicitly upgrades permissions.
- Useful endpoints:
  - ${HOST_AUTOMATION_BASE_URL}/health
  - ${HOST_AUTOMATION_BASE_URL}/v1/system/info
  - ${HOST_AUTOMATION_BASE_URL}/v1/system/apps
  - ${HOST_AUTOMATION_BASE_URL}/v1/desktop/frontmost
  - ${HOST_AUTOMATION_BASE_URL}/v1/browser/frontmost
  - ${HOST_AUTOMATION_BASE_URL}/v1/browser/tabs?app=Google%20Chrome
- If the host agent requires auth, append ?token=<shared-token> to the URL.
EOF

  mv "${tmp_file}" "${user_md}"
}

seed_host_automation_note

provider_json="$(OPENAI_MODEL_ID="${OPENAI_MODEL_ID}" BRIDGE_API_KEY="${BRIDGE_API_KEY}" OPENCODE_BRIDGE_PORT="${OPENCODE_BRIDGE_PORT}" node <<'EOF'
const modelId = process.env.OPENAI_MODEL_ID || "opencode-local";
const apiKey = process.env.BRIDGE_API_KEY || "";
const port = process.env.OPENCODE_BRIDGE_PORT || "8787";
process.stdout.write(
  JSON.stringify({
    baseUrl: `http://127.0.0.1:${port}/v1`,
    apiKey,
    api: "openai-completions",
    models: [{ id: modelId, name: "Opencode Local" }],
  }),
);
EOF
)"

node /app/openclaw.mjs config set gateway.auth.mode token >/dev/null
node /app/openclaw.mjs config set gateway.auth.token "${OPENCLAW_GATEWAY_TOKEN}" >/dev/null
node /app/openclaw.mjs config set gateway.remote.token "${OPENCLAW_GATEWAY_TOKEN}" >/dev/null
node /app/openclaw.mjs config set gateway.controlUi.dangerouslyAllowHostHeaderOriginFallback true --strict-json >/dev/null
node /app/openclaw.mjs config set models.mode merge >/dev/null
node /app/openclaw.mjs config set models.providers.opencode-bridge "${provider_json}" --strict-json >/dev/null
node /app/openclaw.mjs config set agents.defaults.model.primary "opencode-bridge/${OPENAI_MODEL_ID}" >/dev/null

wait_for_port() {
  local port="$1"
  local tries="${2:-60}"
  local i
  for ((i = 0; i < tries; i += 1)); do
    if bash -lc ">/dev/tcp/127.0.0.1/${port}" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

json_count() {
  local file_path="$1"
  if [[ ! -f "${file_path}" ]]; then
    echo 0
    return 0
  fi
  node - "${file_path}" <<'EOF'
const fs = require("node:fs");
const filePath = process.argv[2];
try {
  const raw = fs.readFileSync(filePath, "utf8").trim();
  if (!raw) {
    process.stdout.write("0");
    process.exit(0);
  }
  const data = JSON.parse(raw);
  if (Array.isArray(data)) {
    process.stdout.write(String(data.length));
    process.exit(0);
  }
  if (data && typeof data === "object") {
    process.stdout.write(String(Object.keys(data).length));
    process.exit(0);
  }
} catch {}
process.stdout.write("0");
EOF
}

auto_approve_first_device() {
  if [[ ! "${OPENCLAW_AUTO_APPROVE_FIRST_DEVICE}" =~ ^(1|true|yes)$ ]]; then
    return 0
  fi

  local paired_file="${OPENCLAW_DATA_DIR}/devices/paired.json"
  local pending_file="${OPENCLAW_DATA_DIR}/devices/pending.json"
  local tries=120
  local i
  local paired_count
  local pending_count

  for ((i = 0; i < tries; i += 1)); do
    paired_count="$(json_count "${paired_file}")"
    if [[ "${paired_count}" -gt 0 ]]; then
      return 0
    fi

    pending_count="$(json_count "${pending_file}")"
    if [[ "${pending_count}" -gt 0 ]]; then
      if node /app/openclaw.mjs devices approve --latest >/dev/null 2>&1; then
        echo "auto-approved first pending device" >&2
        return 0
      fi
    fi

    sleep 1
  done
}

cleanup() {
  local code=$?
  trap - EXIT INT TERM
  for pid in "${approver_pid:-}" "${bridge_pid:-}" "${opencode_pid:-}" "${openclaw_pid:-}"; do
    if [[ -n "${pid}" ]] && kill -0 "${pid}" >/dev/null 2>&1; then
      kill "${pid}" >/dev/null 2>&1 || true
    fi
  done
  wait || true
  exit "${code}"
}

trap cleanup EXIT INT TERM

(
  export OPENCODE_AUTH_USERNAME
  export OPENCODE_AUTH_PASSWORD
  export OPENCODE_SERVER_USERNAME="${OPENCODE_AUTH_USERNAME}"
  export OPENCODE_SERVER_PASSWORD="${OPENCODE_AUTH_PASSWORD}"
  exec opencode serve --hostname 127.0.0.1 --port "${LOCAL_OPENCODE_PORT}"
) > >(sed 's/^/[opencode] /') 2>&1 &
opencode_pid=$!

wait_for_port "${LOCAL_OPENCODE_PORT}"

(
  export HOST=0.0.0.0
  export PORT="${OPENCODE_BRIDGE_PORT}"
  export BRIDGE_API_KEY
  export OPENAI_MODEL_ID
  export OPENCODE_BASE_URL="http://127.0.0.1:${LOCAL_OPENCODE_PORT}"
  export OPENCODE_AUTH_MODE=basic
  export OPENCODE_AUTH_USERNAME
  export OPENCODE_AUTH_PASSWORD
  export OPENCODE_PROVIDER_ID
  export OPENCODE_MODEL_ID
  exec node /opt/openclaw-opencode-bridge/server.mjs
) > >(sed 's/^/[bridge] /') 2>&1 &
bridge_pid=$!

wait_for_port "${OPENCODE_BRIDGE_PORT}"

(
  export OPENCLAW_GATEWAY_TOKEN
  exec node /app/openclaw.mjs gateway --allow-unconfigured --bind "${OPENCLAW_GATEWAY_BIND}" --port "${OPENCLAW_GATEWAY_PORT}"
) > >(sed 's/^/[openclaw] /') 2>&1 &
openclaw_pid=$!

(
  auto_approve_first_device
) > >(sed 's/^/[pairing] /') 2>&1 &
approver_pid=$!

echo "all-in-one stack started"
echo "dashboard: http://127.0.0.1:${OPENCLAW_GATEWAY_PORT}"
echo "bridge: http://127.0.0.1:${OPENCODE_BRIDGE_PORT}/v1"
echo "runtime credentials: ${RUNTIME_ENV}"
echo "auto-approve first device: ${OPENCLAW_AUTO_APPROVE_FIRST_DEVICE}"

wait -n "${opencode_pid}" "${bridge_pid}" "${openclaw_pid}"
