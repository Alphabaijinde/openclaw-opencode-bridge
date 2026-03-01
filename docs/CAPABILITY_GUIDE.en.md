# Current Capabilities and Usage Guide

This document answers three practical questions:

1. What the local `OpenClaw + opencode + bridge` stack can do right now
2. How users should start it and use it
3. Which features are planned next

## What Is Available Locally Right Now

The current local setup is built from two pieces:

1. All-in-one image: `ghcr.io/alphabaijinde/openclaw-opencode-bridge:latest`
2. Host-side agent scripts:
   - `scripts/host-automation-agent.mjs`
   - `scripts/start-host-automation-agent.sh`

Responsibilities:

- The all-in-one image contains:
  - OpenClaw
  - opencode
  - opencode-bridge
- The host-side agent performs the real macOS read/write actions

So:

- Pulling the image alone enables chat, but not direct host control
- Running only the host agent is not enough because OpenClaw still needs the container stack
- To get chat plus host access, you need both the container and the host agent

## Current Capability Matrix

| Layer | Mode | What it can do right now | Enabled by default |
| --- | --- | --- | --- |
| In-container chat | all-in-one `latest` | Open the dashboard, chat with OpenClaw, use built-in `opencode + bridge` | Yes |
| Host read-only | `read-only` | Read system info, visible apps, frontmost window, browser frontmost state, browser tabs | No |
| Host browser write | `browser-write` | Activate browser, open URL, reload, switch tabs | No |
| Host desktop write (v1) | `desktop-write` | Activate apps, try to raise a specific window | No |

## What Already Works

### 1. Direct chat

Once the all-in-one image is running, users can open the OpenClaw dashboard and chat immediately.

Current default behavior:

- The installer tries to install and start Docker
- It pulls `latest`
- It starts the container
- It prints a tokenized `Dashboard (direct)` URL
- It auto-approves the first pending device by default
- It prefers the free-model path by default

In many environments, one installer run is enough to open the web UI and start chatting.

### 2. Host read-only access

`read-only` lets containerized OpenClaw inspect the host state without performing write actions.

Current read-only endpoints:

- `GET /health`
- `GET /v1/system/info`
- `GET /v1/system/apps`
- `GET /v1/desktop/frontmost`
- `GET /v1/browser/frontmost`
- `GET /v1/browser/tabs?app=Google%20Chrome`

Optional read-only screenshots (disabled by default):

- `GET /v1/desktop/screenshot`

Useful for:

- letting OpenClaw see which app is currently frontmost
- reading current browser tabs
- reading the current frontmost window title
- building safe “inspect first, act later” flows

### 3. Host browser write

`browser-write` adds a limited browser control layer on top of the read-only layer.

Current browser-write endpoints:

- `POST /v1/browser/activate`
- `POST /v1/browser/open-url`
- `POST /v1/browser/reload`
- `POST /v1/browser/select-tab`

Already tested:

- activating `Google Chrome`
- opening a URL in a new tab on the host Chrome browser
- reloading the active tab
- switching to a specific window/tab

Useful for:

- asking OpenClaw to open a website
- switching back to a specific tab
- refreshing the current page

### 4. Host desktop write (first batch)

`desktop-write` is the first batch of desktop-level write actions that is already implemented.

Current endpoints:

- `POST /v1/desktop/activate-app`
- `POST /v1/desktop/focus-window`

Behavior:

- `activate-app`: brings a target app to the foreground
- `focus-window`: first tries to raise the target window
- if macOS does not expose an accessible window, `focus-window` automatically degrades to `activate-app`
- this means the endpoint no longer hard-fails just because the window cannot be raised

Already tested:

- activating `Google Chrome`
- `focus-window` returning a successful degraded response when the window is not accessible

## How Users Should Use It

### Path A: Chat only, no host access

```bash
git clone https://github.com/Alphabaijinde/openclaw-opencode-bridge.git
cd openclaw-opencode-bridge
./scripts/install-all-in-one.sh
```

After install:

- open the printed `Dashboard (direct)` URL
- if the page is already connected, start chatting
- if you have many older sessions, click `New session`

### Path B: Chat plus host read-only

1. Start the all-in-one stack:

```bash
./scripts/install-all-in-one.sh
```

2. Start the host agent in read-only mode:

```bash
./scripts/start-host-automation-agent.sh
```

3. Reopen the dashboard and preferably start a new session

4. You can now ask OpenClaw to inspect the host, for example:

- "Check which app is frontmost right now"
- "Read my current browser tabs"
- "Show me the current system info"

### Path C: Chat plus host browser control

1. Start the all-in-one stack:

```bash
./scripts/install-all-in-one.sh
```

2. Start the host agent in browser-write mode:

```bash
HOST_AUTOMATION_MODE=browser-write ./scripts/start-host-automation-agent.sh
```

3. Open the dashboard and preferably start a new session

4. You can now ask OpenClaw to perform browser actions, for example:

- "Open Boss Zhipin"
- "Activate Chrome"
- "Refresh Chrome"
- "Switch to the second tab"

### Path D: Chat plus the first desktop-write subset

1. Start the all-in-one stack:

```bash
./scripts/install-all-in-one.sh
```

2. Start the host agent in desktop-write mode:

```bash
HOST_AUTOMATION_MODE=desktop-write ./scripts/start-host-automation-agent.sh
```

3. Open the dashboard and preferably start a new session

4. You can now ask OpenClaw for the first desktop actions, for example:

- "Activate Chrome"
- "Bring Chrome to the front"
- "Try to focus the Chrome window"

## Direct API Usage

If you want to validate the host agent before using OpenClaw, call it directly.

### Check available features

```bash
curl "http://127.0.0.1:4567/health?token=<shared-token>"
```

### Read the frontmost window

```bash
curl "http://127.0.0.1:4567/v1/desktop/frontmost?token=<shared-token>"
```

### Open a website

```bash
curl -X POST "http://127.0.0.1:4567/v1/browser/open-url?token=<shared-token>" \
  -H "Content-Type: application/json" \
  -d '{"app":"Google Chrome","url":"https://www.zhipin.com","newTab":true}'
```

### Activate an app

```bash
curl -X POST "http://127.0.0.1:4567/v1/desktop/activate-app?token=<shared-token>" \
  -H "Content-Type: application/json" \
  -d '{"app":"Google Chrome"}'
```

### Try to raise a window

```bash
curl -X POST "http://127.0.0.1:4567/v1/desktop/focus-window?token=<shared-token>" \
  -H "Content-Type: application/json" \
  -d '{"app":"Google Chrome"}'
```

## Current Permission Boundary

Currently exposed:

- in-container chat
- read host system info
- read the host frontmost window
- read host browser tabs
- open URLs in the host browser
- reload host browser tabs
- switch host browser tabs
- activate host apps
- try to raise host windows

Not currently exposed:

- mouse clicks
- keyboard input
- drag and drop
- arbitrary desktop widget interaction
- arbitrary host command execution
- host-side file mutation workflows

## Things Users Should Know First

- Host access is not provided by the image alone; the host agent must be running
- The recommended launcher is `scripts/start-host-automation-agent.sh` because it generates a token and prints usable URLs
- If you run `node scripts/host-automation-agent.mjs` directly, no token is generated by default
- `desktop-write` is intentionally conservative and still does not expose mouse or keyboard control
- Some macOS actions may trigger system permission prompts:
  - Automation
  - Accessibility
  - Screen Recording (only if screenshots are enabled)

## What Is Planned Next

The next stages should be added gradually by risk level, not all at once.

### Planned `desktop-write` batch two

- basic click actions, first behind explicit confirmation or restricted regions
- basic text input, first as explicit text injection rather than unrestricted global keyboard hooks
- more stable window enumeration and window selection

### Planned `system-write`

- a restricted command allowlist
- opening files or URLs with specific apps
- stricter audit logging and confirmation

### Planned UX improvements

- let the installer optionally start the host agent too
- make the dashboard show the current host permission tier more clearly
- inject the host-agent token into container-side hints automatically
- ship stronger built-in “what I can do right now” prompts

## Recommended Reading

- One-click install: `docs/ALL_IN_ONE_QUICKSTART.en.md`
- Host access playbook: `docs/HOST_ACCESS_PLAYBOOK.en.md`
- Implementation summary: `docs/IMPLEMENTATION_SUMMARY.en.md`
