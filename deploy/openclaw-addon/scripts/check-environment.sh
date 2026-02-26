#!/usr/bin/env bash
set -euo pipefail

OPENCLAW_DIR="${1:-}"
OPENCODE_BIN_CANDIDATES=("${HOME}/.opencode/bin/opencode")

if command -v opencode >/dev/null 2>&1; then
  OPENCODE_BIN_CANDIDATES=("$(command -v opencode)" "${OPENCODE_BIN_CANDIDATES[@]}")
fi

PASS=0
FAIL=0

ok() {
  printf "[OK] %s\n" "$1"
  PASS=$((PASS + 1))
}

warn() {
  printf "[WARN] %s\n" "$1"
}

fail() {
  printf "[FAIL] %s\n" "$1"
  FAIL=$((FAIL + 1))
}

check_cmd() {
  local cmd="$1"
  local install_hint="$2"
  if command -v "${cmd}" >/dev/null 2>&1; then
    ok "${cmd} found: $(command -v "${cmd}")"
  else
    fail "${cmd} not found. ${install_hint}"
  fi
}

echo "== Environment Check =="

check_cmd "git" "Please install git first."
check_cmd "docker" "Please install Docker Desktop / Docker Engine first."

if command -v docker >/dev/null 2>&1; then
  if docker compose version >/dev/null 2>&1; then
    ok "docker compose available"
  else
    fail "docker compose plugin is missing. Install Docker Compose v2 plugin."
  fi

  if docker info >/dev/null 2>&1; then
    ok "docker daemon is reachable"
  else
    fail "docker daemon is not reachable. Start Docker and ensure current user has access."
  fi

  proxy_info="$(docker info 2>/dev/null | grep -E 'HTTP Proxy:|HTTPS Proxy:|No Proxy:' || true)"
  if [[ -n "${proxy_info}" ]]; then
    warn "docker daemon proxy detected:"
    printf "%s\n" "${proxy_info}"
    warn "If pull/build fails, verify those proxy endpoints are reachable on your host."
  fi
fi

found_opencode=""
for bin in "${OPENCODE_BIN_CANDIDATES[@]}"; do
  if [[ -x "${bin}" ]]; then
    found_opencode="${bin}"
    break
  fi
done

if [[ -n "${found_opencode}" ]]; then
  ok "opencode binary found: ${found_opencode}"
else
  fail "opencode binary not found. Install opencode, or prepare OPENCODE_BINARY_PATH."
fi

if [[ -n "${OPENCLAW_DIR}" ]]; then
  if [[ -f "${OPENCLAW_DIR}/docker-compose.yml" ]]; then
    ok "openclaw repo detected: ${OPENCLAW_DIR}"
  else
    warn "openclaw repo not found at ${OPENCLAW_DIR} (installer can clone it automatically)."
  fi
fi

echo
echo "Summary: ${PASS} OK, ${FAIL} FAIL"
if [[ "${FAIL}" -gt 0 ]]; then
  exit 1
fi
