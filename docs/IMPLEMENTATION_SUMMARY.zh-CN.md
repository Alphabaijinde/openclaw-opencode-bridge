# 实现说明（中文）

## 这次做了什么

这次把仓库从一个桥接层项目，收敛成了“用户本地只需要 Docker 就能跑起来”的 all-in-one 交付形态，并额外加上了宿主机联动代理。

核心变化如下：

1. GHCR 只保留一个 package：`openclaw-opencode-bridge`
2. 这个 package 现在有两个 tag：
   - `latest`：all-in-one 单镜像
   - `bridge-only`：原来的 bridge sidecar
3. `latest` 镜像里运行三部分：
   - OpenClaw
   - opencode
   - opencode-bridge
4. 增加了一键安装脚本，负责：
   - 安装/唤起 Docker
   - 拉取镜像
   - 启动容器
   - 输出并打开带 token 的 Dashboard URL
5. 增加了宿主机自动化代理：
   - 默认 `read-only`
   - 可升级到 `browser-write`

## 关键预配置

为了让用户尽量不手工配置，运行时入口脚本会自动写入：

- OpenClaw gateway token
- OpenClaw remote token
- Control UI Host/Origin 兼容配置
- `models.mode=merge`
- `models.providers.opencode-bridge`
- `agents.defaults.model.primary=opencode-bridge/opencode-local`

同时，运行时凭据会落到：

```text
/var/lib/openclaw-opencode/runtime.env
```

包括：

- `RUNTIME_OPENCLAW_GATEWAY_TOKEN`
- `RUNTIME_OPENCODE_AUTH_PASSWORD`
- `RUNTIME_BRIDGE_API_KEY`

## 为什么默认不再强制登录 `opencode`

当前默认链路已经能走免费模型路径，因此“安装后直接聊天”比“先打断用户去登录”更符合一键体验。

因此安装脚本现在改成：

- 默认不主动拉起 `opencode auth login`
- 只在用户显式传 `--opencode-login` 时才启动登录流程
- 安装完成后仍然会打印出可手动执行的登录命令

## 为什么增加带 token 的直达 URL

OpenClaw 控制台如果没有 token，会先报：

- `token missing`
- 或在设备配对阶段进入等待

为了减少用户第一次打开页面时的摩擦，安装脚本在容器起来后会读取运行时 token，并输出：

```text
http://127.0.0.1:18789/#token=<gateway-token>
```

这样用户可以直接进入已带认证信息的 Dashboard。

## 宿主机代理的设计边界

Docker Desktop 上的 Linux 容器不能直接控制 macOS 桌面，所以这里没有给容器直接的宿主机 GUI 权限，而是增加了一层宿主机代理。

当前分层如下：

1. `read-only`
   - 读取系统信息
   - 读取前台窗口
   - 读取浏览器标签
   - 可选截图
2. `browser-write`
   - 激活浏览器
   - 打开 URL
   - 刷新标签页
   - 切换标签页
3. `desktop-write`
   - 预留
4. `system-write`
   - 预留

这样做的目的是把授权边界拆开，避免一开始就给出过大的宿主机控制面。
