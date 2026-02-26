# OpenClaw + Opencode + Feishu (Docker Add-on)

This add-on extends the official OpenClaw Docker deployment with:

- `opencode` server container
- `opencode-bridge` (OpenAI-compatible API for OpenClaw custom provider)
- Feishu plugin env wiring on the OpenClaw `openclaw-gateway` container

## What this add-on assumes

- You deploy OpenClaw using the **official** `docker-compose.yml` from the OpenClaw repo.
- You already installed `opencode` locally on the host machine.

## 1) Quick path (recommended)

Clone both repos, then run one installer command:

```bash
git clone https://github.com/openclaw/openclaw.git
git clone https://github.com/<you>/openclaw-opencode-bridge.git
cd openclaw-opencode-bridge/deploy/openclaw-addon
./scripts/install-openclaw-addon.sh /path/to/openclaw
```

What the installer does:

- prepares `opencode` binary for Docker build context
- installs `docker-compose.override.yml` and `docker/opencode/` into OpenClaw repo
- creates/updates OpenClaw `.env` with required `OPENCODE_*` defaults and generated secrets
- sets `OPENCODE_BRIDGE_CONTEXT` to this bridge repo path

Then start the stack:

```bash
cd /path/to/openclaw
docker compose build opencode opencode-bridge
docker compose up -d
```

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

3) Prepare `opencode` binary:

```bash
cd /path/to/openclaw-opencode-bridge/deploy/openclaw-addon
./scripts/prepare-opencode-binary.sh
```

4) Append values from `.env.additions.example` into OpenClaw `.env`.

## 3) Use opencode free AI (important for your case)

Do this **instead of** setting `OPENAI_API_KEY` / `ANTHROPIC_API_KEY`:

```bash
cd /path/to/openclaw
docker compose exec opencode opencode auth login
docker compose exec opencode opencode auth list
docker compose exec opencode opencode models
```

Then put the chosen provider/model into OpenClaw `.env`:

```bash
OPENCODE_PROVIDER_ID=<provider-id>
OPENCODE_MODEL_ID=<model-id>
```

Restart bridge (or the whole stack):

```bash
docker compose restart opencode-bridge
```

Notes:

- `./opencode-data/share` persists `opencode` auth credentials across restarts.
- The override file mounts `${OPENCODE_INSTALL_DIR}` to `/root/.opencode` so local plugins/runtime can be reused in the container (useful if your free AI path depends on plugins). Default is `./opencode-home`.

## 4) Enable Feishu plugin in OpenClaw

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

## 5) Configure OpenClaw Custom Provider (UI)

Add a Custom Provider in the OpenClaw UI:

- `Base URL`: `http://opencode-bridge:8787/v1` (inside container network) or `http://host.docker.internal:8787/v1` (from host/browser context depending on UI behavior)
- `API Key`: value of `OPENCODE_BRIDGE_API_KEY`
- Model ID: `opencode-local` (or your `OPENCODE_OPENAI_MODEL_ID`)

Practical note:

- OpenClaw backend (`openclaw-gateway`) can reach `opencode-bridge` by service name.
- If the provider call is made from browser directly in your setup, use the host-mapped port (`http://localhost:8787/v1`).

## 6) Configure Feishu app (WebSocket mode)

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
