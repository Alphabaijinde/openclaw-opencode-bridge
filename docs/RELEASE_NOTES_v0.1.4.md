# v0.1.4

发布日期：2026-02-27

## 重点更新

- Docker add-on 默认将 bridge 端口绑定到本机回环地址：
  - `OPENCLAW_PORT_BIND_HOST=127.0.0.1`
  - `OPENCODE_BRIDGE_PORT=8787`
- `opencode` 服务增加兼容环境变量映射：
  - `OPENCODE_SERVER_USERNAME`
  - `OPENCODE_SERVER_PASSWORD`
  - 与 `OPENCODE_AUTH_*` 同步，降低版本差异导致的认证告警。
- 默认拉取策略调整为 `missing`：
  - `OPENCODE_PULL_POLICY=missing`
  - `OPENCODE_BRIDGE_PULL_POLICY=missing`
  - 减少每次启动都强制拉取带来的失败概率。
- 文档补充首次配对流程：
  - `pairing required`
  - `gateway token missing / unauthorized`
  - 对应 `devices approve` 操作和控制台访问路径。
- 根文档与中英文文档统一强调开源最小可用三件套：
  - OpenClaw 官方镜像
  - opencode 预构建镜像
  - opencode-bridge 预构建镜像

## 用户影响

- 新用户按默认安装后更容易一次跑通。
- 默认暴露面更小（bridge 仅本机可访问）。
- 首次启动遇到配对/令牌提示时，定位和恢复路径更明确。
