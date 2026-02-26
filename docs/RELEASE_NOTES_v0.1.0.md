# v0.1.0

发布日期：2026-02-26

## 核心价值

最小可用组合打通：**OpenClaw 可通过 OpenAI 兼容桥接直接使用 opencode 的免费 AI 路径**，在不依赖 OpenAI/Anthropic 官方 API Key 的前提下具备可用 AI 能力。

## 包含内容

- `server.mjs`
  - OpenAI 兼容接口：`/v1/models`、`/v1/chat/completions`、`/health`
  - 请求映射到 opencode session/message API
  - `stream=true` 兼容输出（pseudo-stream）
- Docker 化接入（OpenClaw add-on）
  - `deploy/openclaw-addon/docker-compose.override.yml`
  - `deploy/openclaw-addon/docker/opencode/Dockerfile`
  - `deploy/openclaw-addon/scripts/prepare-opencode-binary.sh`
  - `deploy/openclaw-addon/scripts/local-http-proxy.mjs`
- 开源治理与文档
  - `LICENSE`（MIT）
  - `CONTRIBUTING.md`
  - `SECURITY.md`
  - `docs/OPEN_SOURCE_PLAYBOOK.zh-CN.md`
  - `docs/ARCHITECTURE.md`
  - `docs/TROUBLESHOOTING.md`
  - `docs/RELEASE_CHECKLIST.zh-CN.md`

## 已验证链路

- `docker compose build opencode opencode-bridge` 成功
- `docker compose up -d` 后 `openclaw-gateway`、`opencode`、`opencode-bridge` 均为 `Up`
- `GET /health` 成功
- `GET /v1/models` 成功
- `POST /v1/chat/completions` 成功（烟测返回 `FREE_OK`）
- `openclaw-gateway` 可通过容器网络访问 `http://opencode-bridge:8787`

## 已知边界

- 当前聚焦 `chat.completions` 最小兼容能力
- 非完整 token-by-token 流式转发
- Feishu 端到端联调仍需填写真实 `FEISHU_*` 凭据
