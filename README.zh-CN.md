# OpenClaw + Opencode Bridge（中文）

[English](README.en.md) | [中文](README.zh-CN.md)

本项目提供一个 OpenAI 兼容桥接层，把 OpenClaw 的请求转发到本地 `opencode serve`，用于接入 opencode 的免费 AI 路径。

开源最小可用组合是三件套：

- OpenClaw（官方镜像）
- opencode（预构建镜像）
- opencode-bridge（预构建镜像）

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
docker compose pull
docker compose up -d
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
- `opencode`：默认使用预构建镜像 `ghcr.io/alphabaijinde/openclaw-opencode:latest`（可切换本地构建）
- `opencode-bridge`：默认使用预构建镜像 `ghcr.io/alphabaijinde/openclaw-opencode-bridge:latest`

## 文档入口

- 安装脚本：`deploy/openclaw-addon/scripts/install-openclaw-addon.sh`
- 环境检测：`deploy/openclaw-addon/scripts/check-environment.sh`
- 模型选择：`deploy/openclaw-addon/scripts/select-opencode-model.sh`
- Docker add-on：`deploy/openclaw-addon/README.md`
- 架构说明：`docs/ARCHITECTURE.md`
- 故障排查：`docs/TROUBLESHOOTING.md`
- 发布说明：`docs/RELEASE_NOTES_v0.1.3.md`
