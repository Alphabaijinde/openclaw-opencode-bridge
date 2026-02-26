# OpenClaw + Opencode + Feishu (Docker Add-on)

This add-on extends the official OpenClaw Docker deployment with:

- `opencode` server container
- `opencode-bridge` (OpenAI-compatible API for OpenClaw custom provider)
- Feishu plugin env wiring on the OpenClaw `openclaw-gateway` container

## What this add-on assumes

- You deploy OpenClaw using the **official** `docker-compose.yml` from the OpenClaw repo.
- You already installed `opencode` locally on the host machine (the binary will be copied into the Docker build context).

## 1) Clone OpenClaw (official)

```bash
git clone https://github.com/openclaw/openclaw.git
cd openclaw
cp .env.example .env
```

## 2) Copy this add-on into the OpenClaw repo

Copy these into the OpenClaw repo root:

- `docker-compose.override.yml`
- `docker/opencode/`

Also make sure the bridge repo is available from the OpenClaw repo root, for example:

```bash
git clone https://github.com/<you>/openclaw-opencode-bridge.git ./opencode-bridge
```

Then set `OPENCODE_BRIDGE_CONTEXT=./opencode-bridge` in OpenClaw `.env` (or use an absolute path if you prefer).

## 3) Prepare the opencode binary for Docker build

```bash
cd /path/to/openclaw-opencode-bridge/deploy/openclaw-addon
chmod +x scripts/prepare-opencode-binary.sh
./scripts/prepare-opencode-binary.sh
```

Then copy `docker/opencode/` into the OpenClaw repo (if you haven't yet).

## 4) Add env vars to OpenClaw `.env`

Append values from `.env.additions.example` to the OpenClaw `.env`.

At minimum:

```bash
OPENCODE_AUTH_PASSWORD=change-me
OPENCODE_BRIDGE_API_KEY=change-me
FEISHU_APP_ID=cli_xxx
FEISHU_APP_SECRET=xxx
FEISHU_VERIFICATION_TOKEN=xxx
FEISHU_ENCRYPT_KEY=
```

If you want to use upstream paid model keys with opencode, set them (for example `OPENAI_API_KEY`).

If your goal is to use **opencode's free AI path** (not OpenAI/Anthropic official API keys), you can leave upstream model keys empty and do `opencode auth login` inside the `opencode` container after startup.

## 5) Build and start the stack

From the OpenClaw repo root:

```bash
docker compose build opencode opencode-bridge
docker compose up -d
```

## 5.1) Use opencode free AI (important for your case)

Do this **instead of** setting `OPENAI_API_KEY` / `ANTHROPIC_API_KEY`:

```bash
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

## 6) Enable Feishu plugin in OpenClaw

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

## 7) Configure OpenClaw Custom Provider (UI)

Add a Custom Provider in the OpenClaw UI:

- `Base URL`: `http://opencode-bridge:8787/v1` (inside container network) or `http://host.docker.internal:8787/v1` (from host/browser context depending on UI behavior)
- `API Key`: value of `OPENCODE_BRIDGE_API_KEY`
- Model ID: `opencode-local` (or your `OPENCODE_OPENAI_MODEL_ID`)

Practical note:

- OpenClaw backend (`openclaw-gateway`) can reach `opencode-bridge` by service name.
- If the provider call is made from browser directly in your setup, use the host-mapped port (`http://localhost:8787/v1`).

## 8) Configure Feishu app (WebSocket mode)

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
