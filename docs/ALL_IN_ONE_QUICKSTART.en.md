# All-in-One Quickstart

## Goal

Get a user from zero to a working local OpenClaw chat with as little manual setup as possible:

1. Install Docker
2. Pull `ghcr.io/alphabaijinde/openclaw-opencode-bridge:latest`
3. Start `openclaw + opencode + bridge`
4. Open a direct OpenClaw dashboard URL that is already tokenized

With the current defaults, the image is preconfigured for immediate chat and prefers the bundled free-model path. In many cases, users can start chatting immediately without logging into `opencode` first.

## One-Click Install

```bash
git clone https://github.com/Alphabaijinde/openclaw-opencode-bridge.git
cd openclaw-opencode-bridge
./scripts/install-all-in-one.sh
```

The installer does the following:

1. Checks whether Docker CLI is already available
2. If not:
   - macOS: installs Docker Desktop through Homebrew
   - Debian/Ubuntu: installs `docker.io` and `docker-compose-plugin`
3. Waits for the Docker daemon to become ready
4. Pulls `ghcr.io/alphabaijinde/openclaw-opencode-bridge:latest`
5. Removes any old container with the same name
6. Starts a new container with a persistent data directory
7. Waits until `bridge /health` is healthy
8. Reads the runtime token and API key
9. Prints a direct dashboard URL with the token already attached
10. Opens the default browser automatically in interactive terminals
11. Auto-approves the first pending device by default to reduce first-run pairing friction

## What You Get After Install

The installer prints:

- `Dashboard`
- `Dashboard (direct)`
- `Bridge`
- `OpenClaw token`
- `Bridge API key`
- `Data dir`

The most important value is:

- `Dashboard (direct)`: a URL that already contains the OpenClaw token

It looks like:

```text
http://127.0.0.1:18789/#token=<gateway-token>
```

Opening that link should usually take the user straight into the chat UI.

## If the User Just Wants “Open the Web Page and Chat”

The default recommended path is simply:

```bash
./scripts/install-all-in-one.sh
```

No extra provider setup is required first, and users do not need to manually paste the token. The installer and runtime preconfigure:

- OpenClaw gateway token
- Control UI Host/Origin compatibility setting
- `opencode-bridge` provider
- Default model: `opencode-bridge/opencode-local`
- Mapping from `opencode-local` to the default free-model path in `opencode`
- Automatic approval of the first pending device (enabled by default)

## When to Run `opencode auth login`

The current default model uses the free path, so many setups work immediately.

Only run:

```bash
docker exec -it openclaw-opencode-all-in-one opencode auth login
```

when:

- you want to switch to your own account or provider
- the free path is restricted in your current network environment
- logs show an explicit provider/authentication error

## Common URLs

- Dashboard: `http://127.0.0.1:18789`
- Direct dashboard URL: `http://127.0.0.1:18789/#token=<gateway-token>`
- Bridge: `http://127.0.0.1:8787/v1`

## Host Integration (Optional)

If you want containerized OpenClaw to inspect or control the host, remember that this is a two-part setup:

1. the `latest` image handles the container-side runtime and defaults
2. the host agent scripts perform the actual host-side actions

If you want containerized OpenClaw to inspect host state, start the host agent on the host machine:

```bash
./scripts/start-host-automation-agent.sh
```

Read-only mode supports:

- system information
- visible app list
- current frontmost window
- current frontmost browser tab

If you want browser-only write access, use:

```bash
HOST_AUTOMATION_MODE=browser-write ./scripts/start-host-automation-agent.sh
```

That enables:

- browser activation
- opening URLs
- reloading the current tab
- switching tabs

If you need the first desktop-write subset, use:

```bash
HOST_AUTOMATION_MODE=desktop-write ./scripts/start-host-automation-agent.sh
```

The current desktop-write scope only allows:

- app activation
- raising a specific window

For the full operational sequence, see:

- `docs/HOST_ACCESS_PLAYBOOK.en.md`

## Troubleshooting

If the page does not load or responses do not come back:

1. Check whether the container is still running:

```bash
docker ps --filter name=openclaw-opencode-all-in-one
```

2. Inspect recent logs:

```bash
docker logs --tail 200 openclaw-opencode-all-in-one
```

3. Check bridge health:

```bash
curl http://127.0.0.1:8787/health
```
