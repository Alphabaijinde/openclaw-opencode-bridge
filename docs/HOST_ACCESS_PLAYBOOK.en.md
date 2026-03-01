# Host Access Playbook

## The Core Point

The current “OpenClaw can access the host browser” capability is not provided by the Docker image alone. It is built from two parts:

1. `ghcr.io/alphabaijinde/openclaw-opencode-bridge:latest`
   - runs `openclaw + opencode + bridge`
   - writes the host-agent URL into the OpenClaw workspace hints
2. Host-side agent scripts
   - `scripts/host-automation-agent.mjs`
   - `scripts/start-host-automation-agent.sh`
   - actually call macOS capabilities for host browser / desktop / system access

So:

- Updating the image alone is not enough if the host agent is not running
- Running the host agent alone may still leave an existing container/session unaware of it
- For a clean working setup, update the image and start the host agent together

## What Was Actually Done

To make the current machine capable of host browser access, these steps were actually performed:

1. Pull the latest all-in-one image:

```bash
docker pull ghcr.io/alphabaijinde/openclaw-opencode-bridge:latest
```

The pulled image digest was:

```text
sha256:9c02975d70ea5aa454c372c0780093bd600d5eeb6a3a1c68d0384bd5daecead7
```

2. Recreate the local all-in-one container from the latest image and inject the host-agent URL:

```bash
AUTO_OPEN_DASHBOARD=0 \
HOST_AUTOMATION_BASE_URL=http://host.docker.internal:4567 \
OPENCLAW_AUTO_APPROVE_FIRST_DEVICE=1 \
./scripts/install-all-in-one.sh
```

3. Start the host-side browser-write agent:

```bash
HOST_AUTOMATION_MODE=browser-write \
HOST_AUTOMATION_HOST=0.0.0.0 \
HOST_AUTOMATION_PORT=4567 \
node ./scripts/host-automation-agent.mjs
```

4. Verify that the host agent is healthy:

```bash
curl http://127.0.0.1:4567/health
```

5. Verify that the container can reach the host agent:

```bash
docker exec openclaw-opencode-all-in-one \
  sh -lc 'curl http://host.docker.internal:4567/health'
```

6. Verify that the host browser can actually be opened:

```bash
curl -X POST http://127.0.0.1:4567/v1/browser/open-url \
  -H "Content-Type: application/json" \
  -d '{"app":"Google Chrome","url":"https://www.zhipin.com","newTab":true}'
```

This was tested successfully: the host Chrome browser opened and navigated to Boss Zhipin.

## What Was Changed

### Image-side / container-side

- `deploy/all-in-one/entrypoint.sh`
  - writes the OpenClaw token automatically
  - writes the `opencode-bridge` provider automatically
  - auto-approves the first pending device
  - writes `HOST_AUTOMATION_BASE_URL` into the OpenClaw workspace hints

- `scripts/install-all-in-one.sh`
  - pulls the latest image automatically
  - recreates the container automatically
  - prints a tokenized direct dashboard URL
  - accepts `HOST_AUTOMATION_BASE_URL`
  - no longer forces `opencode auth login` by default

### Host-side access layer

- `scripts/host-automation-agent.mjs`
  - supports `read-only`
  - supports `browser-write`
  - supports reading:
    - system info
    - visible apps
    - frontmost window
    - browser tabs
  - supports browser write actions:
    - browser activation
    - open URL
    - reload
    - switch tab
  - `open-url` now uses macOS `open -a <browser> <url>`, which is more reliable than the earlier direct Chrome AppleScript path

- `scripts/start-host-automation-agent.sh`
  - launches the host agent
  - prints mode, port, and reachable URLs

## Does the “Newest Host-Access-Capable Image” Need a Separate Publish?

The answer depends on which piece changed.

### Changes that do require an image publish

These are inside the image, so they must ship via the image:

- all-in-one entrypoint changes
- container-side defaults
- first-device auto-approval
- workspace host-agent hints
- bridge timeout / empty-response fixes

These are already included in the latest published `latest` image.

### Changes that do not require a new image publish, but must be committed

These run on the host machine, not inside the all-in-one image:

- `scripts/host-automation-agent.mjs`
- `scripts/start-host-automation-agent.sh`

They still need to be committed and pushed to the repo, but they do not require a new container image publish by themselves. Users run them locally on the host after cloning the repo.

## How Users Should Use It

### Chat only, no host access

```bash
./scripts/install-all-in-one.sh
```

Then open the printed `Dashboard (direct)` URL.

### Allow OpenClaw to control the host browser

1. Start the host agent:

```bash
HOST_AUTOMATION_MODE=browser-write ./scripts/start-host-automation-agent.sh
```

2. Make sure the container was recreated from the latest image

3. Open the dashboard and preferably start a new session (`New session`)

4. Ask OpenClaw to perform a browser action such as “open boss”

## Current Boundary

Currently supported:

- read host system info
- read the host frontmost window
- read host browser tabs
- open URLs in the host browser
- reload host browser tabs
- switch host browser tabs

Not currently exposed:

- mouse clicks
- keyboard input
- arbitrary desktop widget interaction
- arbitrary host command execution

Those remain in the future `desktop-write` / `system-write` scope.
