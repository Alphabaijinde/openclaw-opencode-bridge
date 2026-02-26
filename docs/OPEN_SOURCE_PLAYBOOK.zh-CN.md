# OpenClaw + Opencode + Feishu 开源实施文档（桥接核心）

本文档面向准备开源本项目的维护者，目标是：

1. 复盘这套方案是如何从 0 到可运行落地的。
2. 明确“桥接层”作为核心开源内容时，仓库里该放什么。
3. 给出可复现的最小步骤与发布建议。

---

## 1. 项目定位

核心思想：**让 OpenClaw 只对接 OpenAI 兼容接口**，再由本项目桥接到本地 `opencode serve`，最终使用 `opencode` 的登录态/免费模型能力。

也就是说：

- OpenClaw 不直接调用 OpenAI/Anthropic 官方 API（可选）。
- OpenClaw 调用本项目 `opencode-bridge`。
- `opencode-bridge` 调用 `opencode serve`。
- `opencode` 再走其 provider（可包含免费通道）。

---

## 2. 架构概览

```text
OpenClaw (gateway / cli)
      |
      | OpenAI-compatible API
      v
opencode-bridge  (this repo core)
      |
      | opencode server API (/session, /message, ...)
      v
opencode serve
      |
      | provider route (including free models if auth exists)
      v
Model Provider
```

---

## 3. 本次落地过程（实战复盘）

### 3.1 先实现桥接核心

在 `server.mjs` 中实现：

- `GET /v1/models`
- `POST /v1/chat/completions`
- `GET /health`

关键映射：

- OpenAI `messages` -> opencode `parts`（`text`）
- opencode 返回 `parts[type=text]` -> OpenAI `choices[0].message.content`
- 兼容 `stream=true`（先做 pseudo-stream，保证 OpenClaw 兼容性）

关键文件：

- `server.mjs`
- `.env.example`
- `README.md`

### 3.2 修正 opencode 鉴权模式

实测与文档对齐后，桥接支持：

- `basic`（默认）
- `bearer`（兼容场景）

对应环境变量：

- `OPENCODE_AUTH_MODE`
- `OPENCODE_AUTH_USERNAME`
- `OPENCODE_AUTH_PASSWORD`

### 3.3 Docker 化整套链路

新增两类容器：

- `opencode`（用本机二进制打包镜像）
- `opencode-bridge`（Node.js）

并在 OpenClaw 官方 compose 基础上通过 `docker-compose.override.yml` 扩展。

### 3.4 处理实战中的坑

1. Docker daemon 代理错误  
   - daemon 绑定了失效代理 `127.0.0.1:58591`，导致拉镜像失败。  
   - 临时方案：起本地代理让拉取流程先跑通（若有 sudo，建议直接修 systemd docker proxy）。

2. OpenClaw 镜像名变化  
   - `openclaw:local` 默认需要本地构建。  
   - 使用官方可拉取镜像：`ghcr.io/openclaw/openclaw:latest`。

3. OpenClaw 首次启动缺配置  
   - 需先 `setup`，并设置 `gateway.mode=local`。

4. 网关绑定策略  
   - `bind=lan` 时需配置 `gateway.controlUi.allowedOrigins`。  
   - 最小可运行方案可先用 `bind=loopback`。

5. Feishu 插件重复  
   - 镜像已内置 `@openclaw/feishu`，不必重复安装同名插件目录。

6. opencode 免费模型不可用  
   - 根因通常是容器内无 auth 凭据。  
   - 解决：在容器内执行 `opencode auth login` 或导入 `auth.json`。

### 3.5 验证标准（已执行）

- `docker compose ps`：`openclaw-gateway` / `opencode` / `opencode-bridge` 均 `Up`
- 从 `openclaw-gateway` 容器请求 `opencode-bridge`：
  - `POST /v1/chat/completions` 返回 `200`
  - 返回内容与提示一致（例如 `FREE_OK`）
- `opencode models` 能看到免费模型（示例：`opencode/minimax-m2.5-free`）

---

## 4. 开源仓库建议放什么（重点）

建议以“桥接核心仓库”为主，OpenClaw 扩展作为 `deploy/` 示例，不耦合业务私有配置。

## 推荐目录结构

```text
.
├─ server.mjs
├─ package.json
├─ Dockerfile
├─ .env.example
├─ README.md
├─ docs/
│  ├─ OPEN_SOURCE_PLAYBOOK.zh-CN.md
│  ├─ ARCHITECTURE.md
│  └─ TROUBLESHOOTING.md
├─ deploy/
│  └─ openclaw-addon/
│     ├─ docker-compose.override.yml
│     ├─ .env.additions.example
│     ├─ docker/opencode/Dockerfile
│     └─ scripts/prepare-opencode-binary.sh
├─ scripts/
│  └─ (optional healthcheck / smoke test)
├─ LICENSE
├─ CONTRIBUTING.md
├─ SECURITY.md
└─ .gitignore
```

## 必须纳入的文件

- 桥接服务源码与 Dockerfile
- 完整 `.env.example`（不含真实密钥）
- OpenClaw 适配 `override` 示例
- 一份从零部署文档（本文）
- 故障排查文档
- 开源治理文件（`LICENSE`、`CONTRIBUTING`、`SECURITY`）

## 不应提交的内容

- `auth.json`、任何 token/key/cookie
- 本地 `opencode-data` 运行数据
- `.env` 真值文件
- 日志、会话导出、私有业务配置

---

## 5. 最小复现步骤（给开源用户）

1. 启动 `opencode serve`
2. 启动 `opencode-bridge`
3. OpenClaw 自定义 Provider 指向 bridge：
   - `baseURL=http://opencode-bridge:8787/v1`
   - `apiKey=<BRIDGE_API_KEY>`
   - `model=opencode-local`
4. 在 `opencode` 中登录或注入凭据（免费模型路径）
5. 用 `chat.completions` 烟测返回文本

---

## 6. 发布建议

1. 先发 `v0.x`（标注实验性质）
2. CI 做三件事：
   - Node 语法检查
   - Docker 镜像构建
   - 最小 API smoke test（`/health`, `/v1/models`）
3. README 首屏写清兼容边界：
   - 当前实现 focus: chat.completions
   - stream 为兼容模式（非 token-by-token 真流）
4. 版本策略建议：
   - `bridge` 与 `opencode API` 变更解耦（在 release note 记录 tested opencode 版本）

---

## 7. 安全与合规说明（建议写进 README）

- Bridge 仅用于受控网络环境，默认开启 `BRIDGE_API_KEY`
- 生产环境建议放在反向代理后，启用 TLS
- 严禁把 provider 凭据写死在仓库
- 建议限制请求来源与速率（Nginx/Caddy/Traefik 层）

---

## 8. 当前实现的边界（开源时应透明说明）

- 目前是“兼容优先”的 OpenAI API 子集（主要 `chat.completions`）
- 对多模态/函数调用未做完整 OpenAI 语义映射
- 流式输出为兼容实现，不是完整增量 token 转发

---

## 9. 一句话开源定位（建议）

> 一个将本地 `opencode` 能力暴露为 OpenAI 兼容 API 的轻量桥接层，帮助 OpenClaw 等系统无缝接入 `opencode`（含免费模型路径）。

