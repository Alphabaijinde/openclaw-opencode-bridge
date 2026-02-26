# 开源发布检查清单（Release Checklist）

## A. 代码与配置

- [ ] `server.mjs` 可启动，`/health` 返回 `ok`
- [ ] `.env.example` 无真实密钥
- [ ] `deploy/openclaw-addon/.env.additions.example` 无真实密钥
- [ ] 默认配置不包含个人路径（如 `/home/<user>`）
- [ ] 根目录 `.gitignore` 已忽略 `.env`、`opencode-data/`、本地二进制产物

## B. 文档完整性

- [ ] `README.md` 包含快速启动和 OpenClaw 对接示例
- [ ] `deploy/openclaw-addon/README.md` 可独立指导 Docker 部署
- [ ] `docs/ARCHITECTURE.md` 描述请求链路与鉴权边界
- [ ] `docs/TROUBLESHOOTING.md` 覆盖常见故障
- [ ] `docs/OPEN_SOURCE_PLAYBOOK.zh-CN.md` 说明“怎么做的”和“仓库放什么”

## C. 开源治理

- [ ] `LICENSE`（MIT）已确认
- [ ] `CONTRIBUTING.md` 可指导外部贡献
- [ ] `SECURITY.md` 说明漏洞提交流程

## D. Docker 验证

- [ ] `docker compose build opencode opencode-bridge` 成功
- [ ] `docker compose up -d` 后关键服务为 `Up`
- [ ] `curl /v1/models` 返回模型列表
- [ ] `curl /v1/chat/completions` 返回有效文本
- [ ] `stream=true` 请求返回标准 SSE 结构

## E. 免费模型路径验证（你当前目标）

- [ ] 未设置 `OPENAI_API_KEY/ANTHROPIC_API_KEY` 也可工作
- [ ] 容器内 `opencode auth login` 后可见目标免费模型
- [ ] `OPENCODE_PROVIDER_ID` + `OPENCODE_MODEL_ID` 指向免费模型
- [ ] OpenClaw 走自定义 Provider 调用成功

## F. 发布动作

- [ ] 打标签（建议 `v0.x`）
- [ ] Release Note 写明已验证的 OpenClaw/opencode 版本
- [ ] 标注当前 OpenAI 兼容范围（以 `chat.completions` 为主）
