# All-in-One 快速上手（中文）

## 目标

让用户在尽量少的手工操作下完成：

1. 安装 Docker
2. 拉取 `ghcr.io/alphabaijinde/openclaw-opencode-bridge:latest`
3. 启动 `openclaw + opencode + bridge`
4. 自动打开可直接进入的 OpenClaw Dashboard

默认情况下，当前镜像已经预配置为可直接聊天的状态，优先走内置的免费模型路径。多数场景下不需要先登录 `opencode`，打开网页即可开始对话。

## 一键安装

```bash
git clone https://github.com/Alphabaijinde/openclaw-opencode-bridge.git
cd openclaw-opencode-bridge
./scripts/install-all-in-one.sh
```

安装脚本会做这些事：

1. 检查本机是否已有 Docker CLI
2. 如果没有：
   - macOS: 通过 Homebrew 安装 Docker Desktop
   - Debian/Ubuntu: 安装 `docker.io` 和 `docker-compose-plugin`
3. 等待 Docker daemon 就绪
4. 拉取 `ghcr.io/alphabaijinde/openclaw-opencode-bridge:latest`
5. 删除旧的同名容器（如果存在）
6. 用持久化数据目录启动新容器
7. 等待 `bridge /health` 通过
8. 读取运行时 token 和 API key
9. 输出一个带 token 的直达 Dashboard URL
10. 在交互式终端中自动打开默认浏览器
11. 默认自动批准首个待配对设备，减少首次打开时的配对阻塞

## 安装完成后会看到什么

脚本会输出：

- `Dashboard`
- `Dashboard (direct)`
- `Bridge`
- `OpenClaw token`
- `Bridge API key`
- `Data dir`

其中最重要的是：

- `Dashboard (direct)`：这是可直接进入的 URL，已经带好了 OpenClaw token

形式大致如下：

```text
http://127.0.0.1:18789/#token=<gateway-token>
```

直接打开这个链接，通常就能进入聊天页面并开始对话。

## 如果用户只想“打开网页就聊”

默认推荐就是：

```bash
./scripts/install-all-in-one.sh
```

不需要先额外配置 provider，也不需要先手动填写 token。安装脚本会把以下配置预先写好：

- OpenClaw gateway token
- Control UI Host/Origin 兼容配置
- `opencode-bridge` provider
- 默认模型：`opencode-bridge/opencode-local`
- `opencode-local` 到 `opencode` 默认免费模型路径的映射
- 首个待配对设备自动批准（默认开启）

## 什么时候需要再执行 `opencode auth login`

当前默认模型是免费路径，很多情况下可以直接工作。

只有在这些场景下，才建议再执行：

```bash
docker exec -it openclaw-opencode-all-in-one opencode auth login
```

- 你要切到你自己的账号或 provider
- 免费路径在你当前网络环境下不可用
- 你在运行日志里看到了明确的 provider/auth 错误

## 常用地址

- Dashboard: `http://127.0.0.1:18789`
- Dashboard 直达 URL: `http://127.0.0.1:18789/#token=<gateway-token>`
- Bridge: `http://127.0.0.1:8787/v1`

## 宿主机联动（可选）

如果你希望容器里的 OpenClaw 读取或控制宿主机，记住这是“两段式”：

1. `latest` 镜像负责容器内运行和默认配置
2. 宿主机代理脚本负责真正访问宿主机

如果你希望容器里的 OpenClaw 读取宿主机信息，先在宿主机启动代理：

```bash
./scripts/start-host-automation-agent.sh
```

只读模式支持：

- 系统信息
- 可见应用列表
- 当前前台窗口
- 当前前台浏览器标签

如果你希望只开放“浏览器写操作”，可以改成：

```bash
HOST_AUTOMATION_MODE=browser-write ./scripts/start-host-automation-agent.sh
```

这会允许：

- 激活浏览器
- 打开 URL
- 刷新当前标签页
- 切换标签页

完整操作说明见：

- `docs/HOST_ACCESS_PLAYBOOK.zh-CN.md`

## 故障排查

如果安装后网页打不开或没有返回：

1. 看容器是否还在：

```bash
docker ps --filter name=openclaw-opencode-all-in-one
```

2. 看最近日志：

```bash
docker logs --tail 200 openclaw-opencode-all-in-one
```

3. 测 bridge 健康检查：

```bash
curl http://127.0.0.1:8787/health
```
