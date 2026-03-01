# OpenClaw + Opencode Bridge（中文）

[English](README.en.md) | [中文](README.zh-CN.md)

本项目提供一个 OpenAI 兼容桥接层，把 OpenClaw 的请求转发到本地 `opencode serve`，用于接入 opencode 的免费 AI 路径。
本仓库现在只发布一个 GHCR package，但包含两个 tag：

- `latest`：单镜像 all-in-one（`openclaw + opencode + bridge`）
- `bridge-only`：三容器模式下使用的 bridge sidecar tag

## 一键安装（推荐）

用户本地只需要 Docker。安装脚本会尽力自动安装 Docker、启动 Docker Desktop、拉取镜像、注入代理环境并启动容器。安装完成后会输出并尝试自动打开一个已经带 token 的 Dashboard 直达 URL：

```bash
git clone https://github.com/Alphabaijinde/openclaw-opencode-bridge.git
cd openclaw-opencode-bridge
./scripts/install-all-in-one.sh
```

`latest` 单镜像运行时已经内置：

- OpenClaw（官方镜像）
- opencode
- opencode-bridge

默认配置会优先走当前的免费模型路径，很多情况下可以直接聊天，不需要先登录。

同时，all-in-one 默认会自动批准首个待配对设备，避免第一次打开网页时卡在 pairing。

如果你想使用自己的账号 / provider，或者当前网络环境下免费路径不可用，再执行：

```bash
docker exec -it openclaw-opencode-all-in-one opencode auth login
```

更完整的傻瓜式安装说明见：

- `docs/ALL_IN_ONE_QUICKSTART.zh-CN.md`
- `docs/IMPLEMENTATION_SUMMARY.zh-CN.md`
- `docs/HOST_ACCESS_PLAYBOOK.zh-CN.md`

## 宿主机只读代理（浏览器 / 桌面 / 系统）

如果你希望容器里的 OpenClaw 读取当前宿主机的浏览器、桌面前台状态和系统信息，不要让容器直接碰 macOS GUI，而是在宿主机启动一个只读代理：

```bash
cd openclaw-opencode-bridge
./scripts/start-host-automation-agent.sh
```

默认能力（只读）：

- `GET /health`
- `GET /v1/system/info`
- `GET /v1/system/apps`
- `GET /v1/desktop/frontmost`
- `GET /v1/browser/frontmost`
- `GET /v1/browser/tabs?app=Google%20Chrome`

可选截图能力（仍然是只读）默认关闭；需要时再启用：

```bash
HOST_AUTOMATION_ALLOW_SCREENSHOT=1 ./scripts/start-host-automation-agent.sh
```

容器内访问宿主机代理时使用：

```text
http://host.docker.internal:4567
```

如果启动脚本生成了 token，就把它附在 URL 后面：

```text
http://host.docker.internal:4567/v1/system/info?token=<shared-token>
```

这一步只开放读权限，不开放点击、输入、打开应用之类的写操作。后续如果你要，我可以再把它升级成分级授权的读写代理。

如果你要让 OpenClaw 安全地控制宿主机浏览器，可以单独升级到 `browser-write`：

```bash
HOST_AUTOMATION_MODE=browser-write ./scripts/start-host-automation-agent.sh
```

这个模式只开放浏览器写操作，不开放桌面写操作和系统写操作。当前支持：

- `POST /v1/browser/activate`
- `POST /v1/browser/open-url`
- `POST /v1/browser/reload`
- `POST /v1/browser/select-tab`

注意：宿主机访问能力不是只靠 `latest` 镜像本身，还需要宿主机本地运行 `scripts/host-automation-agent.mjs` / `scripts/start-host-automation-agent.sh`。镜像负责容器内配置和提示，宿主机脚本负责真正执行宿主机动作。

示例：

```bash
curl -X POST "http://127.0.0.1:4567/v1/browser/open-url?token=<shared-token>" \
  -H "Content-Type: application/json" \
  -d '{"app":"Google Chrome","url":"https://www.baidu.com","newTab":true}'
```

如果你需要第一个 `desktop-write` 子集，可以升级到：

```bash
HOST_AUTOMATION_MODE=desktop-write ./scripts/start-host-automation-agent.sh
```

当前只开放非常有限的桌面写操作：

- `POST /v1/desktop/activate-app`
- `POST /v1/desktop/focus-window`

这一步只允许激活应用和把指定窗口抬到前台，仍然不开放鼠标点击和键盘输入。

## 三容器模式（高级）

## 核心能力

- `GET /v1/models`
- `POST /v1/chat/completions`
- `GET /health`

## 快速开始（Docker 路径）

```bash
git clone https://github.com/Alphabaijinde/openclaw-opencode-bridge.git
cd openclaw-opencode-bridge/deploy/openclaw-addon
./scripts/check-environment.sh
./scripts/install-openclaw-addon.sh /path/to/openclaw

cd /path/to/openclaw
docker compose pull openclaw-gateway
docker compose up -d --build
docker compose exec opencode opencode auth login
../openclaw-opencode-bridge/deploy/openclaw-addon/scripts/select-opencode-model.sh /path/to/openclaw
docker compose restart opencode-bridge
```

默认桥接端口仅绑定本机：

```bash
OPENCLAW_PORT_BIND_HOST=127.0.0.1
OPENCODE_BRIDGE_PORT=8787
```

## 产物说明

- `openclaw-gateway`：使用 OpenClaw 官方镜像
- `latest`：单镜像，内含 `openclaw + opencode + bridge`
- `bridge-only`：只包含 bridge，用于三容器模式

## 文档入口

- 一键安装快速上手：`docs/ALL_IN_ONE_QUICKSTART.zh-CN.md`
- 实现说明：`docs/IMPLEMENTATION_SUMMARY.zh-CN.md`
- 宿主机访问说明：`docs/HOST_ACCESS_PLAYBOOK.zh-CN.md`
- 安装脚本：`deploy/openclaw-addon/scripts/install-openclaw-addon.sh`
- 环境检测：`deploy/openclaw-addon/scripts/check-environment.sh`
- 模型选择：`deploy/openclaw-addon/scripts/select-opencode-model.sh`
- Docker add-on：`deploy/openclaw-addon/README.md`
- 架构说明：`docs/ARCHITECTURE.md`
- 故障排查：`docs/TROUBLESHOOTING.md`
- 发布说明：`docs/RELEASE_NOTES_v0.1.4.md`
