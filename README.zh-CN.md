# OpenClaw + Opencode Bridge（中文）

[English](README.en.md) | [中文](README.zh-CN.md)

本项目提供一个 OpenAI 兼容桥接层，把 OpenClaw 的请求转发到本地 `opencode serve`，用于接入 opencode 的免费 AI 路径。
本仓库现在只发布一个 GHCR package，但包含两个 tag：

- `latest`：单镜像 all-in-one（`openclaw + opencode + bridge`）
- `bridge-only`：三容器模式下使用的 bridge sidecar tag

## 一键安装（推荐）

用户本地只需要 Docker。安装脚本会尽力自动安装 Docker、启动 Docker Desktop、拉取镜像、注入代理环境并启动容器：

```bash
git clone https://github.com/Alphabaijinde/openclaw-opencode-bridge.git
cd openclaw-opencode-bridge
./scripts/install-all-in-one.sh
```

`latest` 单镜像运行时已经内置：

- OpenClaw（官方镜像）
- opencode
- opencode-bridge

首次使用免费 AI 路径时，仍需完成一次登录：

```bash
docker exec -it openclaw-opencode-all-in-one opencode auth login
```

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

- 安装脚本：`deploy/openclaw-addon/scripts/install-openclaw-addon.sh`
- 环境检测：`deploy/openclaw-addon/scripts/check-environment.sh`
- 模型选择：`deploy/openclaw-addon/scripts/select-opencode-model.sh`
- Docker add-on：`deploy/openclaw-addon/README.md`
- 架构说明：`docs/ARCHITECTURE.md`
- 故障排查：`docs/TROUBLESHOOTING.md`
- 发布说明：`docs/RELEASE_NOTES_v0.1.4.md`
