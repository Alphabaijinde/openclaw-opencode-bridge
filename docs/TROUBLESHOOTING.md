# Troubleshooting

## Quick Health Checks

```bash
curl -s http://127.0.0.1:8787/health
curl -s http://127.0.0.1:8787/v1/models -H "Authorization: Bearer ${BRIDGE_API_KEY}"
```

Docker mode:

```bash
docker compose ps
docker compose logs --tail=100 opencode-bridge
docker compose logs --tail=100 opencode
```

## 401 Unauthorized (from bridge)

Symptoms:
- `/v1/models` or `/v1/chat/completions` returns `401`

Checks:
- `BRIDGE_API_KEY` in bridge env
- `Authorization: Bearer <same key>` from OpenClaw/custom client

## 401/403 from opencode (seen in bridge logs)

Symptoms:
- bridge returns 5xx with opencode auth error payload

Checks:
- `OPENCODE_AUTH_MODE` is correct (`basic` by default)
- `OPENCODE_AUTH_USERNAME` and `OPENCODE_AUTH_PASSWORD` match opencode server config

## No free models available

Symptoms:
- `opencode models` inside container shows no expected free model

Fix:

```bash
docker compose exec opencode opencode auth login
docker compose exec opencode opencode auth list
docker compose exec opencode opencode models
```

Then set:

```env
OPENCODE_PROVIDER_ID=<provider-id>
OPENCODE_MODEL_ID=<model-id>
```

Restart bridge:

```bash
docker compose restart opencode-bridge
```

## OpenClaw cannot reach bridge

Symptoms:
- provider call timeout/connection refused

Checks:
- If OpenClaw runs in Docker, use `http://opencode-bridge:8787/v1` from gateway network.
- If calling from host/browser, use `http://127.0.0.1:8787/v1` (or mapped host IP/port).
- verify `OPENCODE_BRIDGE_PORT` mapping in compose.

## Build fails: missing `opencode` binary in add-on Docker context

Symptoms:
- `COPY opencode /usr/local/bin/opencode` fails

Fix:

```bash
cd deploy/openclaw-addon
chmod +x scripts/prepare-opencode-binary.sh
./scripts/prepare-opencode-binary.sh
```

Rebuild:

```bash
docker compose build opencode
```

## Feishu plugin not taking effect

Checks:
- Plugin enabled in OpenClaw (`plugins enable feishu`)
- `FEISHU_*` env vars injected into `openclaw-gateway`
- gateway restarted after env/plugin changes
