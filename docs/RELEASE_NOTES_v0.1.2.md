# v0.1.2

发布日期：2026-02-26

## 重点更新

- 新增环境检测脚本：`deploy/openclaw-addon/scripts/check-environment.sh`
- 一键安装脚本集成环境检测并自动补齐关键 `.env` 变量
- 新增模型选择脚本：`deploy/openclaw-addon/scripts/select-opencode-model.sh`
- 默认提供 `OPENCODE_PROVIDER_ID=opencode` + `OPENCODE_MODEL_ID=minimax-m2.5-free`
- Docker add-on 支持宿主机代理透传（`HOST_HTTP_PROXY`/`HOST_HTTPS_PROXY`/`HOST_NO_PROXY`）
- 默认优先使用预构建桥接镜像：
  - `ghcr.io/alphabaijinde/openclaw-opencode-bridge:latest`
- 新增 GHCR 自动发布工作流：
  - `.github/workflows/publish-bridge-image.yml`

## 用户影响

- 首次部署路径缩短为：环境检测 -> 一键安装 -> 启动 -> 登录 opencode -> 选择模型
- 对宿主机代理环境（如 Clash Verge `7897`）更友好
- 不再要求每次都本地构建 `opencode-bridge`（可直接拉取镜像）
