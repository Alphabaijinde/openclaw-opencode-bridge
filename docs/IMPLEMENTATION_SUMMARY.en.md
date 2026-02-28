# Implementation Summary

## What Changed

This repo was tightened from “just a bridge project” into an all-in-one local deliverable where the user only needs Docker, plus an optional host integration layer.

The main changes are:

1. GHCR now keeps a single package: `openclaw-opencode-bridge`
2. That package now has two tags:
   - `latest`: the all-in-one image
   - `bridge-only`: the legacy bridge sidecar
3. The `latest` image runs three parts:
   - OpenClaw
   - opencode
   - opencode-bridge
4. A one-click installer now:
   - installs or launches Docker
   - pulls the image
   - starts the container
   - prints and opens a tokenized dashboard URL
5. A host automation agent was added:
   - default `read-only`
   - optional `browser-write`

## Key Preconfiguration

To minimize manual setup, the runtime entrypoint automatically writes:

- OpenClaw gateway token
- OpenClaw remote token
- Control UI Host/Origin compatibility setting
- `models.mode=merge`
- `models.providers.opencode-bridge`
- `agents.defaults.model.primary=opencode-bridge/opencode-local`

Runtime credentials are persisted in:

```text
/var/lib/openclaw-opencode/runtime.env
```

including:

- `RUNTIME_OPENCLAW_GATEWAY_TOKEN`
- `RUNTIME_OPENCODE_AUTH_PASSWORD`
- `RUNTIME_BRIDGE_API_KEY`

## Why `opencode` Login Is No Longer Forced by Default

The current default chain can already use the free-model path, so “install and chat immediately” is a better default than interrupting users with a login flow.

The installer now behaves like this:

- it does not start `opencode auth login` by default
- it only starts the login flow when the user explicitly passes `--opencode-login`
- it still prints the manual login command after install

## Why the Installer Prints a Tokenized Direct URL

Without a token, the OpenClaw dashboard can first hit:

- `token missing`
- or wait during device pairing

To reduce first-run friction, the installer reads the runtime token after the container starts and prints:

```text
http://127.0.0.1:18789/#token=<gateway-token>
```

That lets the user open a dashboard URL that already contains the required authentication.

## Host Agent Design Boundary

On Docker Desktop, a Linux container cannot directly control the macOS desktop. Instead of giving the container direct host GUI access, this repo now uses a host-side automation agent.

Current permission tiers:

1. `read-only`
   - read system information
   - read the frontmost window
   - read browser tabs
   - optional screenshots
2. `browser-write`
   - activate the browser
   - open URLs
   - reload tabs
   - switch tabs
3. `desktop-write`
   - reserved
4. `system-write`
   - reserved

This keeps authorization boundaries explicit instead of exposing broad host control from the start.
