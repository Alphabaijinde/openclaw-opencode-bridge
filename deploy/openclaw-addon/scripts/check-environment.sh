#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  check-environment.sh [openclaw-dir] [--auto-install] [--yes] [--require-opencode-binary]

Options:
  --auto-install   Try to install missing git/docker/docker compose (best effort)
  --yes            Non-interactive mode for package installs
  --require-opencode-binary  Fail when local opencode binary is missing
USAGE
}

OPENCLAW_DIR=""
AUTO_INSTALL=0
ASSUME_YES=0
REQUIRE_OPENCODE_BINARY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --auto-install)
      AUTO_INSTALL=1
      shift
      ;;
    --yes)
      ASSUME_YES=1
      shift
      ;;
    --require-opencode-binary)
      REQUIRE_OPENCODE_BINARY=1
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

OPENCODE_BIN_CANDIDATES=("${HOME}/.opencode/bin/opencode")
if command -v opencode >/dev/null 2>&1; then
  OPENCODE_BIN_CANDIDATES=("$(command -v opencode)" "${OPENCODE_BIN_CANDIDATES[@]}")
fi

PASS=0
FAIL=0
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"

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

run_privileged() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    return 1
  fi
}

apt_install() {
  local packages=("$@")
  local apt_y="-y"
  if [[ "${ASSUME_YES}" -eq 0 ]]; then
    apt_y=""
  fi
  run_privileged apt-get update
  run_privileged apt-get install ${apt_y} "${packages[@]}"
}

brew_install() {
  local packages=("$@")
  command -v brew >/dev/null 2>&1 || return 1
  brew install "${packages[@]}"
}

try_install_cmd() {
  local cmd="$1"
  if [[ "${AUTO_INSTALL}" -ne 1 ]]; then
    return 1
  fi

  if [[ "${OS}" == "linux" ]] && command -v apt-get >/dev/null 2>&1; then
    case "${cmd}" in
      git) apt_install git ;;
      docker) apt_install docker.io docker-compose-plugin ;;
      docker-compose-plugin) apt_install docker-compose-plugin ;;
      *) return 1 ;;
    esac
    return 0
  fi

  if [[ "${OS}" == "darwin" ]]; then
    case "${cmd}" in
      git) brew_install git ;;
      docker) command -v brew >/dev/null 2>&1 && brew install --cask docker ;;
      docker-compose-plugin) brew_install docker-compose ;;
      *) return 1 ;;
    esac
    return 0
  fi

  return 1
}

check_cmd() {
  local cmd="$1"
  local install_hint="$2"
  if command -v "${cmd}" >/dev/null 2>&1; then
    ok "${cmd} found: $(command -v "${cmd}")"
  else
    if try_install_cmd "${cmd}" && command -v "${cmd}" >/dev/null 2>&1; then
      ok "${cmd} installed: $(command -v "${cmd}")"
    else
      fail "${cmd} not found. ${install_hint}"
    fi
  fi
}

echo "== Environment Check =="
check_cmd "git" "Please install git first."
check_cmd "docker" "Please install Docker Desktop / Docker Engine first."

if command -v docker >/dev/null 2>&1; then
  if docker compose version >/dev/null 2>&1; then
    ok "docker compose available"
  else
    if try_install_cmd "docker-compose-plugin" && docker compose version >/dev/null 2>&1; then
      ok "docker compose installed"
    else
      fail "docker compose plugin is missing. Install Docker Compose v2 plugin."
    fi
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
  if [[ "${REQUIRE_OPENCODE_BINARY}" -eq 1 ]]; then
    fail "opencode binary not found. Install opencode first, or prepare OPENCODE_BINARY_PATH."
  else
    warn "opencode binary not found (OK for prebuilt image mode)."
  fi
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
  if [[ "${AUTO_INSTALL}" -eq 1 ]]; then
    warn "Auto-install is best effort. Some dependencies still need manual install/start."
  fi
  exit 1
fi
