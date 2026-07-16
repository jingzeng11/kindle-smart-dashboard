# Kindle Smart Dashboard

把越狱 Kindle 8（KT3）变成低功耗的 Apple 风格电子墨水日历显示屏。

当前已完成 V0.4：只读 Apple Calendar 日程 + 成都双流区实时天气 → 每小时自动生成 macOS 原生 PNG → 登录后自动运行的局域网 HTTP 服务。Kindle 端下载与屏幕刷新仍未接入。

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

生成结果为 600 × 800 竖屏 PNG，包含中文日程、模拟待办和天气排版数据。

显式选择日程和天气数据源：

```bash
swift run DashboardCLI render --source mock --weather mock --output ./output/dashboard.png
open -W ".build/Kindle Smart Dashboard Calendar Access.app" --args render --source calendar --weather live --output "$PWD/output/dashboard.png"
```

`--weather live` 默认使用成都双流区坐标 `30.58, 103.92` 和 `Asia/Shanghai` 时区。可用 `--latitude`、`--longitude` 覆盖坐标。实时请求失败时会读取 `~/Library/Caches/KindleSmartDashboard/weather.json` 中最后一次成功结果；从未成功获取且网络不可用时，命令会返回明确错误，不会覆盖已有 PNG。

## Apple Calendar 权限试验

查看当前权限状态：

```bash
swift run DashboardCLI calendar-status
```

请求只读日历所需的完整访问权限：

```bash
./Scripts/build-calendar-authorizer.sh
open -W ".build/Kindle Smart Dashboard Calendar Access.app" --args calendar-authorize
```

macOS 不会为裸 SwiftPM 可执行文件显示 TCC 权限弹窗，因此脚本会把同一个 CLI 二进制封装成无界面的本地签名 App Bundle。授权后，通过 App Bundle 执行 `render --source calendar` 即可读取当天 Apple Calendar 日程。日历内容仅在本机处理，原始数据不会上传或单独写盘；局域网中能访问 HTTP 接口的设备可以看到 PNG 中已渲染的日程文字。

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

## 安装每小时自动刷新

安装当前用户的两个 LaunchAgent：

```bash
./Scripts/install-dashboard-automation.sh
```

安装脚本会把签名 App 复制到稳定位置、确认日历权限、立即生成首张真实数据图片，并启动以下任务：

- `com.jingzeng.kindle-smart-dashboard.refresh`：登录时运行，此后每小时刷新一次；
- `com.jingzeng.kindle-smart-dashboard.server`：登录时启动并持续监听 `0.0.0.0:8080`。

服务地址：

```text
http://<Mac局域网IP>:8080/health
http://<Mac局域网IP>:8080/dashboard.png
```

运行数据位于 `~/Library/Application Support/KindleSmartDashboard`，日志位于 `~/Library/Logs/KindleSmartDashboard`。卸载：

```bash
./Scripts/uninstall-dashboard-automation.sh
```

## 项目结构

- `DashboardModels`：日程、待办和快照模型
- `DashboardCalendar`：Apple Calendar 权限、当天区间和 EventKit 只读查询
- `DashboardWeather`：双流区实时天气、WMO 天气代码转换和本地缓存降级
- `DashboardRenderer`：600 × 800 原生 PNG 渲染器
- `DashboardServer`：小型局域网 HTTP 服务
- `DashboardCLI`：`render` 与 `serve` 命令

完整的 V0.1 范围与验收标准见 [docs/PROJECT_SPEC.md](docs/PROJECT_SPEC.md)。

V0.2 的只读 Apple Calendar 接入约束与验收标准见 [docs/APPLE_CALENDAR_INTEGRATION.md](docs/APPLE_CALENDAR_INTEGRATION.md)。

V0.3 的实时天气设计与验收记录见 [docs/WEATHER_INTEGRATION.md](docs/WEATHER_INTEGRATION.md)。天气数据由 [Open-Meteo](https://open-meteo.com/) 提供，采用 [CC BY 4.0](https://open-meteo.com/en/license) 许可；本项目将摄氏温度取整并把 WMO 天气代码转换为简短中文描述。

V0.4 的 macOS 自动刷新和服务安装说明见 [docs/MAC_AUTOMATION.md](docs/MAC_AUTOMATION.md)。
