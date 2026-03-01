# 当前能力总览与使用手册（中文）

这份文档专门回答三个问题：

1. 现在本地这套 `OpenClaw + opencode + bridge` 已经具备哪些能力
2. 用户应该怎么启动、怎么用
3. 接下来还准备补哪些能力

## 当前本地可用组件

当前本地可用的整体能力由两部分组成：

1. all-in-one 容器镜像：`ghcr.io/alphabaijinde/openclaw-opencode-bridge:latest`
2. 宿主机代理脚本：
   - `scripts/host-automation-agent.mjs`
   - `scripts/start-host-automation-agent.sh`

二者分工如下：

- all-in-one 镜像内包含：
  - OpenClaw
  - opencode
  - opencode-bridge
- 宿主机代理负责真正读取或操作当前 macOS 宿主机

结论：

- 只拉镜像，可以聊天，但不能直接控制宿主机
- 只启动宿主机代理，不启动容器，OpenClaw 也无法对话
- 要“对话 + 访问宿主机”，需要容器和宿主机代理一起工作

## 当前能力矩阵

| 层级 | 模式 | 当前可用能力 | 默认是否开启 |
| --- | --- | --- | --- |
| 容器内聊天 | all-in-one `latest` | 打开 Dashboard、和 OpenClaw 对话、走内置 `opencode + bridge` | 是 |
| 宿主机只读 | `read-only` | 读取系统信息、可见应用、前台窗口、浏览器前台状态、浏览器标签页 | 否 |
| 宿主机浏览器写 | `browser-write` | 激活浏览器、打开 URL、刷新、切换标签页 | 否 |
| 宿主机桌面写（第一版） | `desktop-write` | 激活应用、尝试抬起指定窗口 | 否 |

## 当前已经可用的具体能力

### 1. 直接聊天

all-in-one 镜像启动后，用户可以直接打开 OpenClaw Dashboard 对话。

当前默认行为：

- 安装脚本会尽量自动安装并启动 Docker
- 自动拉取 `latest`
- 自动启动容器
- 自动输出一个带 token 的 `Dashboard (direct)` 直达地址
- 默认自动批准首个待配对设备
- 默认优先尝试免费模型路径

很多环境下，用户执行一次安装脚本后就可以直接打开网页聊天。

### 2. 宿主机只读能力

`read-only` 模式下，可以让容器里的 OpenClaw 读取当前宿主机状态，但不能执行写操作。

当前只读接口：

- `GET /health`
- `GET /v1/system/info`
- `GET /v1/system/apps`
- `GET /v1/desktop/frontmost`
- `GET /v1/browser/frontmost`
- `GET /v1/browser/tabs?app=Google%20Chrome`

可选只读截图（默认关闭）：

- `GET /v1/desktop/screenshot`

适合的用途：

- 让 OpenClaw 知道你当前在用哪个应用
- 让 OpenClaw 读取当前浏览器标签页
- 让 OpenClaw 读取当前前台窗口标题
- 做“先看再决策”的安全自动化

### 3. 宿主机浏览器写能力

`browser-write` 模式会在只读能力基础上，增加浏览器层的安全写操作。

当前浏览器写接口：

- `POST /v1/browser/activate`
- `POST /v1/browser/open-url`
- `POST /v1/browser/reload`
- `POST /v1/browser/select-tab`

当前已实测可用：

- 激活 `Google Chrome`
- 在宿主机 Chrome 新标签页打开 URL
- 刷新前台标签页
- 切换到指定窗口/标签页

适合的用途：

- 让 OpenClaw 打开某个网站
- 让 OpenClaw 切回某个标签页
- 让 OpenClaw 刷新当前网页

### 4. 宿主机桌面写能力（第一版）

`desktop-write` 是当前已经做好的第一批桌面写能力。

当前接口：

- `POST /v1/desktop/activate-app`
- `POST /v1/desktop/focus-window`

行为说明：

- `activate-app`：把指定应用拉到前台
- `focus-window`：优先尝试抬起目标窗口
- 如果 macOS 没有给到可访问窗口，`focus-window` 会自动降级为 `activate-app`
- 这意味着即使窗口提起失败，接口也不会直接硬报错

当前已实测可用：

- 激活 `Google Chrome`
- `focus-window` 在窗口不可访问时返回成功降级

## 用户怎么用

### 路径 A：只聊天，不访问宿主机

```bash
git clone https://github.com/Alphabaijinde/openclaw-opencode-bridge.git
cd openclaw-opencode-bridge
./scripts/install-all-in-one.sh
```

安装完成后：

- 打开终端输出里的 `Dashboard (direct)`
- 如果页面已经可用，直接开始聊天
- 如果你切换过很多旧会话，建议点一次 `New session`

### 路径 B：聊天 + 宿主机只读

1. 启动 all-in-one：

```bash
./scripts/install-all-in-one.sh
```

2. 启动宿主机只读代理：

```bash
./scripts/start-host-automation-agent.sh
```

3. 重新打开 Dashboard，最好新开一个会话

4. 现在可以让 OpenClaw 先读取宿主机信息，例如：

- “看看我现在前台是什么应用”
- “读一下我当前浏览器标签页”
- “看看当前系统信息”

### 路径 C：聊天 + 控制宿主机浏览器

1. 启动 all-in-one：

```bash
./scripts/install-all-in-one.sh
```

2. 启动浏览器写代理：

```bash
HOST_AUTOMATION_MODE=browser-write ./scripts/start-host-automation-agent.sh
```

3. 打开 Dashboard，建议 `New session`

4. 现在可以直接让 OpenClaw 做浏览器动作，例如：

- “打开 Boss 直聘”
- “激活 Chrome”
- “把 Chrome 刷新一下”
- “切到第二个标签页”

### 路径 D：聊天 + 第一版桌面写

1. 启动 all-in-one：

```bash
./scripts/install-all-in-one.sh
```

2. 启动桌面写代理：

```bash
HOST_AUTOMATION_MODE=desktop-write ./scripts/start-host-automation-agent.sh
```

3. 打开 Dashboard，建议 `New session`

4. 现在可以让 OpenClaw 做第一批桌面动作，例如：

- “激活 Chrome”
- “把 Chrome 拉到前台”
- “尝试切到 Chrome 窗口”

## 直接调接口的用法

如果你想先绕过 OpenClaw，直接验证宿主机代理，可以这样测试。

### 查看能力

```bash
curl "http://127.0.0.1:4567/health?token=<shared-token>"
```

### 读取前台应用

```bash
curl "http://127.0.0.1:4567/v1/desktop/frontmost?token=<shared-token>"
```

### 打开一个网页

```bash
curl -X POST "http://127.0.0.1:4567/v1/browser/open-url?token=<shared-token>" \
  -H "Content-Type: application/json" \
  -d '{"app":"Google Chrome","url":"https://www.zhipin.com","newTab":true}'
```

### 激活一个应用

```bash
curl -X POST "http://127.0.0.1:4567/v1/desktop/activate-app?token=<shared-token>" \
  -H "Content-Type: application/json" \
  -d '{"app":"Google Chrome"}'
```

### 尝试抬起一个窗口

```bash
curl -X POST "http://127.0.0.1:4567/v1/desktop/focus-window?token=<shared-token>" \
  -H "Content-Type: application/json" \
  -d '{"app":"Google Chrome"}'
```

## 当前权限与边界

当前已经开放：

- 容器内对话
- 读取宿主机系统信息
- 读取宿主机前台窗口
- 读取宿主机浏览器标签页
- 在宿主机浏览器打开 URL
- 刷新宿主机浏览器标签页
- 切换宿主机浏览器标签页
- 激活宿主机应用
- 尝试抬起宿主机窗口

当前还没有开放：

- 鼠标点击
- 键盘输入
- 拖拽
- 任意桌面控件交互
- 任意宿主机命令执行
- 文件改写类宿主机自动化

## 使用前需要知道的事

- 宿主机能力不是镜像单独提供的，必须启动宿主机代理
- 推荐用 `scripts/start-host-automation-agent.sh` 启动，因为它会自动生成 token 并打印地址
- 如果你直接用 `node scripts/host-automation-agent.mjs`，默认不会生成 token
- `desktop-write` 仍然是保守实现，不会开放鼠标和键盘
- 某些 macOS 动作会要求系统弹出权限授权：
  - Automation
  - Accessibility
  - Screen Recording（只有启用截图时才需要）

## 后续计划补什么

下一阶段计划按风险逐步加，不会一次性全部放开。

### 计划中的 `desktop-write` 第二批

- 基础点击（先做显式确认或限定区域）
- 基础输入（先做显式文本注入，不做全局键盘钩子）
- 更稳定的窗口选择和窗口索引读取

### 计划中的 `system-write`

- 受限命令白名单
- 指定应用打开文件或 URL
- 更严格的审计日志和确认机制

### 计划中的体验优化

- 安装脚本联动启动宿主机代理
- 在 Dashboard 中更明确提示当前宿主机权限层级
- 自动把宿主机代理 token 写入容器侧提示
- 增加更多“当前能做什么”的内置提示语

## 推荐阅读

- 一键安装：`docs/ALL_IN_ONE_QUICKSTART.zh-CN.md`
- 宿主机接入说明：`docs/HOST_ACCESS_PLAYBOOK.zh-CN.md`
- 实现说明：`docs/IMPLEMENTATION_SUMMARY.zh-CN.md`
