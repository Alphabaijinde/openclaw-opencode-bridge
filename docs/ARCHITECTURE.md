# Architecture

## Goal

Expose local `opencode serve` as an OpenAI-compatible API so OpenClaw can use it as a Custom Provider.

## Components

- `openclaw-gateway`: calls OpenAI-compatible endpoints.
- `opencode-bridge` (this repo): translates OpenAI requests to opencode session/message APIs.
- `opencode`: executes model calls using its configured providers (including free-model path when logged in).

## Data Flow

1. OpenClaw sends `POST /v1/chat/completions` to `opencode-bridge`.
2. Bridge verifies `Authorization: Bearer <BRIDGE_API_KEY>`.
3. Bridge maps OpenAI `messages` to opencode prompt/system input.
4. Bridge creates an opencode session (`POST /session/new`).
5. Bridge sends prompt to opencode (`POST /session/{id}/message`).
6. Bridge converts opencode text parts back to OpenAI response shape.
7. Bridge returns JSON completion or SSE-compatible pseudo-stream.

## Model Resolution Order

Bridge resolves the target provider/model in this order:

1. `MODEL_MAP_JSON[openaiModel]`
2. inline model syntax from request model (`provider/model` or `provider:model`)
3. defaults from `OPENCODE_PROVIDER_ID` + `OPENCODE_MODEL_ID`

If none are available, bridge returns a `400` error.

## Auth Boundaries

- Client -> Bridge:
  - controlled by `BRIDGE_API_KEY`
- Bridge -> opencode:
  - `OPENCODE_AUTH_MODE=basic|bearer|none`
  - `basic` uses `OPENCODE_AUTH_USERNAME` + `OPENCODE_AUTH_PASSWORD`

## Runtime Modes

- Local mode:
  - run `opencode serve` directly on host
  - run bridge with `npm start`
- Docker add-on mode:
  - use `deploy/openclaw-addon/docker-compose.override.yml`
  - run `opencode`, `opencode-bridge`, and OpenClaw in one compose stack

## Known Compatibility Limits

- API scope is intentionally small (`/v1/models`, `/v1/chat/completions`, `/health`).
- Streaming is compatibility-oriented pseudo-stream, not token-by-token forwarding.
- Tool/function-calling and multimodal parity are not fully implemented.
