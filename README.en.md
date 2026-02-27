# OpenClaw + Opencode Bridge

[English](README.en.md) | [中文](README.zh-CN.md)

This bridge exposes an OpenAI-compatible API for OpenClaw and forwards requests to a local `opencode serve` instance.

For open-source deployment, the minimum runnable stack is:

- OpenClaw (official image)
- opencode (prebuilt image)
- opencode-bridge (prebuilt image)

## Open Source Guide

- Quick Docker install: `deploy/openclaw-addon/scripts/install-openclaw-addon.sh`
- Environment check: `deploy/openclaw-addon/scripts/check-environment.sh`
- GHCR image: `ghcr.io/alphabaijinde/openclaw-opencode-bridge:latest`
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
docker compose pull
docker compose up -d
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
