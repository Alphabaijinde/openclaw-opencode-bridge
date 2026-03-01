#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPT="${SCRIPT_DIR}/host-automation-agent.mjs"

HOST_AUTOMATION_HOST="${HOST_AUTOMATION_HOST:-0.0.0.0}"
HOST_AUTOMATION_PORT="${HOST_AUTOMATION_PORT:-4567}"
HOST_AUTOMATION_MODE="${HOST_AUTOMATION_MODE:-read-only}"
HOST_AUTOMATION_ALLOW_SCREENSHOT="${HOST_AUTOMATION_ALLOW_SCREENSHOT:-0}"

if [[ -z "${HOST_AUTOMATION_TOKEN:-}" ]]; then
  HOST_AUTOMATION_TOKEN="$(
    node -e "const { randomBytes } = require('node:crypto'); process.stdout.write(randomBytes(24).toString('hex'));"
  )"
fi

export HOST_AUTOMATION_HOST
export HOST_AUTOMATION_PORT
export HOST_AUTOMATION_MODE
export HOST_AUTOMATION_ALLOW_SCREENSHOT
export HOST_AUTOMATION_TOKEN

echo "Starting host automation agent"
echo "  listen: http://${HOST_AUTOMATION_HOST}:${HOST_AUTOMATION_PORT}"
echo "  mode:   ${HOST_AUTOMATION_MODE}"
echo "  token:  ${HOST_AUTOMATION_TOKEN}"
echo
echo "Container-friendly URLs:"
echo "  health:   http://host.docker.internal:${HOST_AUTOMATION_PORT}/health?token=${HOST_AUTOMATION_TOKEN}"
echo "  system:   http://host.docker.internal:${HOST_AUTOMATION_PORT}/v1/system/info?token=${HOST_AUTOMATION_TOKEN}"
echo "  desktop:  http://host.docker.internal:${HOST_AUTOMATION_PORT}/v1/desktop/frontmost?token=${HOST_AUTOMATION_TOKEN}"
echo "  browser:  http://host.docker.internal:${HOST_AUTOMATION_PORT}/v1/browser/frontmost?token=${HOST_AUTOMATION_TOKEN}"
if [[ "${HOST_AUTOMATION_MODE}" != "read-only" ]]; then
  echo "  browser write: POST http://host.docker.internal:${HOST_AUTOMATION_PORT}/v1/browser/open-url?token=${HOST_AUTOMATION_TOKEN}"
fi
if [[ "${HOST_AUTOMATION_MODE}" == "desktop-write" || "${HOST_AUTOMATION_MODE}" == "system-write" ]]; then
  echo "  desktop write: POST http://host.docker.internal:${HOST_AUTOMATION_PORT}/v1/desktop/activate-app?token=${HOST_AUTOMATION_TOKEN}"
fi
echo
echo "macOS permissions that may be requested:"
echo "  - Automation"
echo "  - Accessibility"
echo "  - Screen Recording (only if HOST_AUTOMATION_ALLOW_SCREENSHOT=1)"
echo
echo "Modes:"
echo "  - read-only     (default)"
echo "  - browser-write (open URL / activate / reload / switch tabs)"
echo "  - desktop-write (browser-write + activate app / focus window)"
echo "  - system-write  (reserved)"
echo

exec node "${AGENT_SCRIPT}"
