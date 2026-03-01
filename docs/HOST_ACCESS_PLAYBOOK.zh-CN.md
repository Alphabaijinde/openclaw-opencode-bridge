# 宿主机访问接入说明（中文）

## 结论先说

当前“OpenClaw 可以访问宿主机浏览器”的能力，不是只靠 Docker 镜像单独实现的，而是由两部分共同组成：

1. `ghcr.io/alphabaijinde/openclaw-opencode-bridge:latest`
   - 负责运行 `openclaw + opencode + bridge`
   - 容器内会把宿主机代理地址写入工作区提示
2. 宿主机代理脚本
   - `scripts/host-automation-agent.mjs`
   - `scripts/start-host-automation-agent.sh`
   - 负责真正调用 macOS 能力，访问宿主机浏览器 / 桌面 / 系统

所以：

- 仅更新镜像，不启动宿主机代理，仍然不能操作宿主机浏览器
- 仅启动宿主机代理，不重建容器，当前会话里的 OpenClaw 也不一定知道去用它
- 要让“当前这台机器”真正可用，推荐同时完成镜像更新和宿主机代理启动

## 这次实际做了哪些操作

这次为了让当前机器具备宿主机浏览器访问能力，实际执行了以下步骤：

1. 拉取最新 all-in-one 镜像：

```bash
docker pull ghcr.io/alphabaijinde/openclaw-opencode-bridge:latest
```

当前拉到的镜像摘要是：

```text
sha256:9c02975d70ea5aa454c372c0780093bd600d5eeb6a3a1c68d0384bd5daecead7
```

2. 用最新镜像重建本地 all-in-one 容器，同时把宿主机代理地址注入进去：

```bash
AUTO_OPEN_DASHBOARD=0 \
HOST_AUTOMATION_BASE_URL=http://host.docker.internal:4567 \
OPENCLAW_AUTO_APPROVE_FIRST_DEVICE=1 \
./scripts/install-all-in-one.sh
```

3. 在宿主机启动浏览器写权限代理：

```bash
HOST_AUTOMATION_MODE=browser-write \
HOST_AUTOMATION_HOST=0.0.0.0 \
HOST_AUTOMATION_PORT=4567 \
node ./scripts/host-automation-agent.mjs
```

4. 确认宿主机代理是健康的：

```bash
curl http://127.0.0.1:4567/health
```

5. 确认容器内能访问宿主机代理：

```bash
docker exec openclaw-opencode-all-in-one \
  sh -lc 'curl http://host.docker.internal:4567/health'
```

6. 确认宿主机浏览器实际可被打开：

```bash
curl -X POST http://127.0.0.1:4567/v1/browser/open-url \
  -H "Content-Type: application/json" \
  -d '{"app":"Google Chrome","url":"https://www.zhipin.com","newTab":true}'
```

这一步已经实测成功，宿主机 Chrome 已被成功打开并跳转到 Boss 直聘。

## 这次改了哪些代码 / 脚本

### 镜像相关（容器侧）

- `deploy/all-in-one/entrypoint.sh`
  - 自动写入 OpenClaw token
  - 自动写入 `opencode-bridge` provider
  - 自动批准首个待配对设备
  - 自动把 `HOST_AUTOMATION_BASE_URL` 写进 OpenClaw 工作区提示

- `scripts/install-all-in-one.sh`
  - 自动拉最新镜像
  - 自动重建容器
  - 输出带 token 的直达 Dashboard URL
  - 允许传入 `HOST_AUTOMATION_BASE_URL`
  - 默认不再强制要求 `opencode auth login`

### 宿主机访问相关（宿主机侧）

- `scripts/host-automation-agent.mjs`
  - 提供 `read-only` 模式
  - 提供 `browser-write` 模式
  - 支持读取：
    - 系统信息
    - 可见应用
    - 前台窗口
    - 浏览器标签
  - 支持浏览器写操作：
    - 激活浏览器
    - 打开 URL
    - 刷新
    - 切换标签页
  - `open-url` 现在使用 macOS `open -a <browser> <url>`，比之前直接走 Chrome AppleScript 更稳

- `scripts/start-host-automation-agent.sh`
  - 启动宿主机代理
  - 输出当前模式、端口、可访问地址

## “最新具有访问能力的镜像”要不要单独提交 / 重新发

结论：分两部分看。

### 需要通过镜像发布的部分

以下内容在镜像里，因此需要随镜像发布：

- all-in-one 入口脚本变更
- 容器内默认配置
- 自动配对首设备
- 工作区里的宿主机代理提示
- bridge 超时 / 空响应修复

这些已经通过最新 `latest` 镜像发布完成。

### 不需要重新发镜像、但必须提交仓库的部分

以下内容是宿主机本地运行的脚本，不在 all-in-one 容器镜像里：

- `scripts/host-automation-agent.mjs`
- `scripts/start-host-automation-agent.sh`

它们必须提交到仓库并推送，但不需要为了它们单独重发容器镜像。用户从仓库拉脚本后，在宿主机本地运行即可。

## 用户最终怎么用

### 只聊天，不碰宿主机

```bash
./scripts/install-all-in-one.sh
```

然后打开安装输出的 `Dashboard (direct)`。

### 允许 OpenClaw 控制宿主机浏览器

1. 启动宿主机代理：

```bash
HOST_AUTOMATION_MODE=browser-write ./scripts/start-host-automation-agent.sh
```

2. 确保容器是最新镜像重建出来的

3. 打开 Dashboard，建议新开一个会话（`New session`）

4. 再让 OpenClaw 执行浏览器操作，例如“打开 boss”

## 当前边界

当前已经支持：

- 读取宿主机系统信息
- 读取宿主机前台窗口
- 读取宿主机浏览器标签
- 打开宿主机浏览器 URL
- 刷新宿主机浏览器标签页
- 切换宿主机浏览器标签页

当前还没有开放：

- 鼠标点击
- 键盘输入
- 任意桌面控件操作
- 任意宿主机命令执行

这些属于后续的 `desktop-write` / `system-write` 范围。
