# OpenClaw + Opencode Bridge

[English](README.en.md) | [中文](README.zh-CN.md)

This bridge exposes an OpenAI-compatible API for OpenClaw and forwards requests to a local `opencode serve` instance.
This repo publishes a single GHCR package with two tags:

- `latest`: all-in-one image (`openclaw + opencode + bridge`) for one-command installs
- `bridge-only`: bridge sidecar tag used by the three-container Docker add-on

## One-click all-in-one (recommended)

Users only need Docker. The installer can install Docker (best effort), pull the all-in-one image, apply proxy env, and start the container. After startup it prints and tries to open a direct dashboard URL that already includes the token:

```bash
git clone https://github.com/Alphabaijinde/openclaw-opencode-bridge.git
cd openclaw-opencode-bridge
./scripts/install-all-in-one.sh
```

The all-in-one runtime includes:

- OpenClaw (official image)
- opencode
- opencode-bridge

The current defaults prefer the free-model path, so many setups can chat immediately without logging in first.

The all-in-one runtime also auto-approves the first pending device by default, which avoids the first-run pairing prompt in most cases.

Only run this if you want your own account/provider, or the free path is blocked in your environment:

```bash
docker exec -it openclaw-opencode-all-in-one opencode auth login
```

For the full zero-to-chat walkthrough, see:

- `docs/ALL_IN_ONE_QUICKSTART.en.md`
- `docs/IMPLEMENTATION_SUMMARY.en.md`
- `docs/HOST_ACCESS_PLAYBOOK.en.md`

## Read-only host agent (browser / desktop / system)

If you want containerized OpenClaw to inspect the current host browser, frontmost desktop state, and system details, do not grant the container direct macOS GUI control. Run a small read-only agent on the host instead:

```bash
cd openclaw-opencode-bridge
./scripts/start-host-automation-agent.sh
```

Default read-only endpoints:

- `GET /health`
- `GET /v1/system/info`
- `GET /v1/system/apps`
- `GET /v1/desktop/frontmost`
- `GET /v1/browser/frontmost`
- `GET /v1/browser/tabs?app=Google%20Chrome`

Optional screenshots are still read-only, but disabled by default:

```bash
HOST_AUTOMATION_ALLOW_SCREENSHOT=1 ./scripts/start-host-automation-agent.sh
```

From inside the container, use:

```text
http://host.docker.internal:4567
```

If the launcher generated a token, append it to the URL:

```text
http://host.docker.internal:4567/v1/system/info?token=<shared-token>
```

This keeps the first phase read-only. We can layer in write actions later behind separate authorization.

If you want OpenClaw to safely control the host browser, upgrade only the browser layer to `browser-write`:

```bash
HOST_AUTOMATION_MODE=browser-write ./scripts/start-host-automation-agent.sh
```

This enables browser write actions only. It does not enable desktop-write or system-write. Current browser write endpoints:

- `POST /v1/browser/activate`
- `POST /v1/browser/open-url`
- `POST /v1/browser/reload`
- `POST /v1/browser/select-tab`

Important: host access is not provided by the `latest` image alone. It also requires the host-side scripts `scripts/host-automation-agent.mjs` / `scripts/start-host-automation-agent.sh`. The image configures the container-side hints; the host scripts execute the real host actions.

Example:

```bash
curl -X POST "http://127.0.0.1:4567/v1/browser/open-url?token=<shared-token>" \
  -H "Content-Type: application/json" \
  -d '{"app":"Google Chrome","url":"https://www.baidu.com","newTab":true}'
```

If you need the first `desktop-write` subset, upgrade to:

```bash
HOST_AUTOMATION_MODE=desktop-write ./scripts/start-host-automation-agent.sh
```

The current desktop-write scope is intentionally narrow:

- `POST /v1/desktop/activate-app`
- `POST /v1/desktop/focus-window`

This only allows app activation and raising a specific window. It still does not expose mouse clicks or keyboard input.

## Three-container add-on (advanced)

## Open Source Guide

- Quick Docker install: `deploy/openclaw-addon/scripts/install-openclaw-addon.sh`
- Environment check: `deploy/openclaw-addon/scripts/check-environment.sh`
- GHCR package: `ghcr.io/alphabaijinde/openclaw-opencode-bridge`
- Release notes v0.1.4: `docs/RELEASE_NOTES_v0.1.4.md`
- Chinese playbook: `docs/OPEN_SOURCE_PLAYBOOK.zh-CN.md`
- Release checklist (zh-CN): `docs/RELEASE_CHECKLIST.zh-CN.md`
- Architecture: `docs/ARCHITECTURE.md`
- Troubleshooting: `docs/TROUBLESHOOTING.md`
- Docker add-on guide: `deploy/openclaw-addon/README.md`
- Contribution guide: `CONTRIBUTING.md`
- Security policy: `SECURITY.md`
- License: `LICENSE` (MIT)

## What it provides

- `GET /v1/models`
- `POST /v1/chat/completions` (non-stream + pseudo-stream SSE)
- `GET /health`

## Recommended Docker path (full stack)

Use the add-on installer to set up OpenClaw + opencode + bridge together:

```bash
git clone https://github.com/Alphabaijinde/openclaw-opencode-bridge.git
cd openclaw-opencode-bridge/deploy/openclaw-addon
./scripts/check-environment.sh
./scripts/install-openclaw-addon.sh /path/to/openclaw
cd /path/to/openclaw
docker compose pull openclaw-gateway
docker compose up -d --build
docker compose exec opencode opencode auth login
../openclaw-opencode-bridge/deploy/openclaw-addon/scripts/select-opencode-model.sh /path/to/openclaw
docker compose restart opencode-bridge
```

## 1) Start opencode headless server

```bash
export OPENCODE_AUTH_PASSWORD=change-me
opencode serve --hostname 127.0.0.1 --port 4096
```

## 2) Start this bridge

```bash
cd /path/to/openclaw-opencode-bridge
cp .env.example .env
set -a && source .env && set +a
npm start
```

## 3) Test the OpenAI-compatible endpoint

```bash
curl http://127.0.0.1:8787/v1/models \
  -H "Authorization: Bearer change-me"
```

```bash
curl http://127.0.0.1:8787/v1/chat/completions \
  -H "Authorization: Bearer change-me" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "opencode-local",
    "messages": [{"role":"user","content":"你好，介绍一下你自己"}]
  }'
```

## Model mapping options

- Default: set `OPENCODE_PROVIDER_ID` + `OPENCODE_MODEL_ID`
- Per-model mapping: set `MODEL_MAP_JSON`
- Inline model syntax from OpenClaw:
  - `provider/model`
  - `provider:model`

Examples:

- `anthropic/claude-sonnet-4-5`
- `openai:gpt-4.1-mini`

## Notes

- Each OpenAI request creates a new opencode session (stateless compatibility).
- `stream=true` is supported as OpenAI SSE format, but the content is emitted in one chunk after opencode returns.

## OpenClaw provider config (Custom Provider)

In OpenClaw's provider config (UI or config file), add a custom provider that points to this bridge.

```yaml
providers:
  - type: custom
    id: opencode-bridge
    name: Opencode Bridge
    apiKey: ${OPENCODE_BRIDGE_API_KEY}
    baseURL: http://host.docker.internal:8787/v1
    models:
      - id: opencode-local
        name: Opencode Local
        supportsVision: false
```

Important:

- If OpenClaw runs in Docker, do not use `127.0.0.1` for `baseURL`.
- Use `host.docker.internal` (Mac/Windows), or your host LAN IP.
- On Linux Docker, you may need `--add-host=host.docker.internal:host-gateway`.

## OpenClaw -> Feishu (Lark) setup

1) Install the Feishu plugin in OpenClaw (inside the OpenClaw deployment):

```bash
openclaw plugins install @openclaw/feishu
```

2) Set these plugin env vars for the OpenClaw gateway container:

```bash
FEISHU_APP_ID=cli_xxx
FEISHU_APP_SECRET=xxx
FEISHU_VERIFICATION_TOKEN=xxx
FEISHU_ENCRYPT_KEY=xxx   # optional if disabled in Feishu
```

3) In Feishu developer console:

- Create a bot app
- Configure the Feishu bot event subscription (the OpenClaw plugin uses Feishu WebSocket mode, so you do not need a public webhook callback URL)
- Subscribe to the required message events
- Publish the app and install it into the target chat/group

If your OpenClaw host is behind a restricted outbound proxy/firewall, make sure the OpenClaw gateway container can establish outbound WebSocket connections to Feishu.
