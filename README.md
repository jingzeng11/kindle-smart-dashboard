# Kindle Smart Dashboard

把越狱 Kindle 8（KT3）变成低功耗的 Apple 风格电子墨水日历显示屏。

V0.1 只验证一条最小链路：模拟日历与天气数据 → macOS 原生 PNG 渲染 → 本地 HTTP 服务。天气目前只用于排版验证，不包含真实接口、定位或自动更新；Kindle 端自动刷新与真实 Apple Calendar 接入也不在本阶段范围内。

## 环境要求

- macOS 13 或更新版本（目标环境为 macOS 14+）
- Swift 5.8 或更新版本；代码保持 Swift 6 兼容
- 局域网内可访问这台 Mac

项目没有第三方依赖。

## 构建与测试

```bash
swift build
swift test
```

## 生成仪表盘图片

```bash
swift run DashboardCLI render --output ./output/dashboard.png
```

生成结果为 600 × 800 竖屏 PNG，包含中文模拟日程和待办事项。

## 启动本地服务

先生成图片，再启动服务器：

```bash
swift run DashboardCLI serve --host 0.0.0.0 --port 8080
```

验证接口：

```bash
curl http://127.0.0.1:8080/health
curl --output /tmp/dashboard.png http://127.0.0.1:8080/dashboard.png
```

- `GET /health` 返回 `ok`。
- `GET /dashboard.png` 返回最新生成的图片。
- 图片不存在时，接口返回明确的 `404` 信息，服务不会崩溃。

## 项目结构

- `DashboardModels`：日程、待办和快照模型
- `DashboardRenderer`：600 × 800 原生 PNG 渲染器
- `DashboardServer`：小型局域网 HTTP 服务
- `DashboardCLI`：`render` 与 `serve` 命令

完整的 V0.1 范围与验收标准见 [docs/PROJECT_SPEC.md](docs/PROJECT_SPEC.md)。

下一阶段的只读 Apple Calendar 接入约束与验收标准见 [docs/APPLE_CALENDAR_INTEGRATION.md](docs/APPLE_CALENDAR_INTEGRATION.md)。
