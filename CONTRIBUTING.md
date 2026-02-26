# Contributing

Thanks for contributing to `openclaw-opencode-bridge`.

## Scope

- Keep this project focused on one goal: expose `opencode` as an OpenAI-compatible API for OpenClaw-like clients.
- Prefer small, composable changes over large rewrites.

## Development

```bash
npm start
```

Bridge endpoints:

- `GET /health`
- `GET /v1/models`
- `POST /v1/chat/completions`

## Pull Request Rules

1. Open an issue first for behavior changes or API changes.
2. Keep backward compatibility whenever possible.
3. Add or update docs for any user-visible change.
4. Include a short test/proof in PR description:
   - sample request
   - sample response
5. Do not commit secrets (`.env`, tokens, auth.json, logs).

## Commit Style (recommended)

- `feat: ...` new behavior
- `fix: ...` bug fix
- `docs: ...` documentation only
- `refactor: ...` no behavior change
- `chore: ...` maintenance

## Code Style

- Prefer clear, explicit code over abstractions.
- Keep dependencies minimal.
- Preserve existing env variable compatibility unless strongly justified.

