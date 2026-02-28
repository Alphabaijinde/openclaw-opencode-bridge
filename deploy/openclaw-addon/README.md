# OpenClaw + Opencode Bridge (Docker Add-on)

This add-on extends the official OpenClaw Docker deployment with:

- `opencode` server container
- `opencode-bridge` (OpenAI-compatible API for OpenClaw custom provider)
- optional Feishu plugin env wiring on the OpenClaw `openclaw-gateway` container

## What this add-on assumes

- You deploy OpenClaw using the **official** `docker-compose.yml` from the OpenClaw repo.
- Docker is available on the host.
- No host `opencode` install is required in the default path.

## 1) Quick path (recommended)

Clone this bridge repo, run environment check, then one installer command:

```bash
git clone https://github.com/Alphabaijinde/openclaw-opencode-bridge.git
cd openclaw-opencode-bridge/deploy/openclaw-addon
./scripts/check-environment.sh
./scripts/install-openclaw-addon.sh /path/to/openclaw
```

Notes:

- If `/path/to/openclaw` does not exist, installer will clone official OpenClaw automatically.
- Installer asks for `OPENCODE_PROVIDER_ID` / `OPENCODE_MODEL_ID` and writes `.env`.
- If dependencies are missing, you can try auto-install mode:
  - `./scripts/install-openclaw-addon.sh /path/to/openclaw --auto-install`
  - add `--yes` for non-interactive package installation.

What the installer does:

- prepares `opencode` binary for Docker build context
- installs `docker-compose.override.yml` and `docker/opencode/` into OpenClaw repo
- creates/updates OpenClaw `.env` with required `OPENCODE_*` defaults and generated secrets
- sets `OPENCODE_BRIDGE_CONTEXT` to this bridge repo path

Then start the stack:

```bash
cd /path/to/openclaw
docker compose pull openclaw-gateway opencode-bridge
docker compose up -d --build
```

OpenClaw Dashboard default URL:

```text
http://127.0.0.1:18789/
```

By default, `opencode` is built during compose and `opencode-bridge` uses the `bridge-only` tag from the shared package:

```bash
OPENCODE_IMAGE=openclaw-opencode-local:latest
OPENCODE_PULL_POLICY=never
OPENCODE_BUILD_CONTEXT=./docker/opencode-prebuilt
OPENCODE_BRIDGE_IMAGE=ghcr.io/alphabaijinde/openclaw-opencode-bridge:bridge-only
```

Default host binding for bridge is localhost only:

```bash
OPENCLAW_PORT_BIND_HOST=127.0.0.1
OPENCODE_BRIDGE_PORT=8787
```

If you want to rebuild manually:

```bash
docker compose build opencode
docker compose build opencode-bridge
```

## 1.1) Container image sources (important)

- `openclaw-gateway` / `openclaw-cli`: OpenClaw official image (`OPENCLAW_IMAGE`, default `ghcr.io/openclaw/openclaw:latest`).
- `opencode`: built locally by default into `openclaw-opencode-local:latest` from the bundled Dockerfile; users do not need a host `opencode` install.
- `opencode-bridge`: prebuilt sidecar tag by default (`ghcr.io/alphabaijinde/openclaw-opencode-bridge:bridge-only`), local build optional.

This means a standard startup includes all three runtime components:

- OpenClaw (official image)
- opencode server
- opencode-bridge

## 2) Manual path (advanced)

If you do not want the installer script, do this manually:

1) Clone OpenClaw and prepare `.env`:

```bash
git clone https://github.com/openclaw/openclaw.git
cd openclaw
cp .env.example .env
```

2) Copy add-on files into OpenClaw repo root:

 - `docker-compose.override.yml`
 - `docker/opencode/`

3) For the default Docker-native path, no host `opencode` install is needed. If you explicitly want host-binary mode instead:

```bash
cd /path/to/openclaw-opencode-bridge/deploy/openclaw-addon
./scripts/prepare-opencode-binary.sh
```

4) In OpenClaw `.env`, set the build mode you want:

```bash
OPENCODE_PULL_POLICY=never
OPENCODE_BUILD_CONTEXT=./docker/opencode-prebuilt
```

5) Append values from `.env.additions.example` into OpenClaw `.env`.

## 3) Use opencode free AI (important for your case)

Do this **instead of** setting `OPENAI_API_KEY` / `ANTHROPIC_API_KEY`:

```bash
cd /path/to/openclaw
docker compose exec opencode opencode auth login
docker compose exec opencode opencode auth list
docker compose exec opencode opencode models
```

Then run model selector:

```bash
/path/to/openclaw-opencode-bridge/deploy/openclaw-addon/scripts/select-opencode-model.sh /path/to/openclaw
```

Restart bridge (or the whole stack):

```bash
docker compose restart opencode-bridge
```

Notes:

- `./opencode-data/share` persists `opencode` auth credentials across restarts.
- The override file mounts `${OPENCODE_INSTALL_DIR}` to `/root/.opencode` so local plugins/runtime can be reused in the container (useful if your free AI path depends on plugins). Default is `./opencode-home`.

## 3.1) What are `OPENCODE_PROVIDER_ID` and `OPENCODE_MODEL_ID`?

- `OPENCODE_PROVIDER_ID`: opencode provider namespace (for example `opencode`, `openai`, `anthropic`).
- `OPENCODE_MODEL_ID`: concrete model under that provider.

This project defaults to:

```bash
OPENCODE_PROVIDER_ID=opencode
OPENCODE_MODEL_ID=minimax-m2.5-free
```

You can keep defaults, or reselect after login with `select-opencode-model.sh`.

## 3.2) Proxy configuration (host -> containers)

If OpenClaw/opencode need outbound proxy, set these in OpenClaw `.env`:

```bash
HOST_HTTP_PROXY=http://host.docker.internal:7897
HOST_HTTPS_PROXY=http://host.docker.internal:7897
HOST_NO_PROXY=localhost,127.0.0.1,opencode,opencode-bridge,host.docker.internal
```

Example above is for Clash Verge default HTTP proxy on `7897`.

Important:

- This config affects container runtime/build env.
- Docker daemon pull proxy is a separate setting. Do not hard-code old local ports like `58591` unless that proxy endpoint is really alive on your machine.

## 4) Pair dashboard device once (if chat page shows `pairing required`)

```bash
docker compose run --rm openclaw-cli devices list
docker compose run --rm openclaw-cli devices approve --latest
docker compose restart openclaw-gateway
```

If chat page shows token error, open the full dashboard URL from gateway logs and use that tokenized URL once.

## 5) Configure OpenClaw Custom Provider (UI)

Add a Custom Provider in the OpenClaw UI:

- `Base URL`: `http://opencode-bridge:8787/v1` (inside container network) or `http://host.docker.internal:8787/v1` (from host/browser context depending on UI behavior)
- `API Key`: value of `OPENCODE_BRIDGE_API_KEY`
- Model ID: `opencode-local` (or your `OPENCODE_OPENAI_MODEL_ID`)

Practical note:

- OpenClaw backend (`openclaw-gateway`) can reach `opencode-bridge` by service name.
- If the provider call is made from browser directly in your setup, use the host-mapped port (`http://localhost:8787/v1`).

## 6) Enable Feishu plugin in OpenClaw (optional)

Most OpenClaw images already include `@openclaw/feishu` as a stock plugin. Enable it:

```bash
docker compose run --rm openclaw-cli plugins enable feishu
docker compose restart openclaw-gateway
```

If your OpenClaw build does not bundle it, install explicitly:

```bash
docker compose run --rm openclaw-cli plugins install @openclaw/feishu
docker compose restart openclaw-gateway
```

## 7) Configure Feishu app (WebSocket mode)

In Feishu developer console:

- Create the bot app
- Enable bot/message events
- Configure event subscription for the bot
- No public webhook callback is required for the OpenClaw Feishu plugin (WebSocket mode)
- Publish and install the app

## Quick checks

```bash
docker compose ps
curl http://127.0.0.1:${OPENCODE_BRIDGE_PORT:-8787}/health
curl http://127.0.0.1:${OPENCODE_BRIDGE_PORT:-8787}/v1/models \
  -H "Authorization: Bearer ${OPENCODE_BRIDGE_API_KEY}"
```

## Notes

- The bridge is stateless (each request creates a new `opencode` session).
- `opencode` data is persisted under `./opencode-data/` in the OpenClaw repo.
- The override file relies on OpenClaw official service names `openclaw-gateway` and `openclaw-cli`.
