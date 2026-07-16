# macOS Automation

## Status

V0.4 was installed and verified on 2026-07-16.

## Jobs

The user-level installer creates two LaunchAgents without requiring administrator privileges:

| Label | Behavior |
| --- | --- |
| `com.jingzeng.kindle-smart-dashboard.refresh` | Runs at login and every 3600 seconds. It opens the signed helper app and renders real Calendar plus live Shuangliu weather. |
| `com.jingzeng.kindle-smart-dashboard.server` | Runs at login, stays alive, and serves the current PNG on port 8080. |

The refresh job is intentionally hourly to limit unnecessary Calendar reads, weather requests, and disk writes.

## Install

```bash
./Scripts/install-dashboard-automation.sh
```

The installer:

1. builds and signs the helper app;
2. installs it under `~/Library/Application Support/KindleSmartDashboard`;
3. requests Calendar access through the stable installed app identity;
4. performs one real Calendar and live-weather render;
5. installs and bootstraps both LaunchAgents.

Re-running the installer safely replaces the installed app and jobs.

## Runtime paths

```text
~/Library/Application Support/KindleSmartDashboard/
  Kindle Smart Dashboard Calendar Access.app
  data/dashboard.png

~/Library/Logs/KindleSmartDashboard/
  refresh.log
  server.log
  error.log
```

The installed runtime does not depend on the repository remaining at the same path.

## Verification

```bash
launchctl print "gui/$UID/com.jingzeng.kindle-smart-dashboard.refresh"
launchctl print "gui/$UID/com.jingzeng.kindle-smart-dashboard.server"
curl http://127.0.0.1:8080/health
curl --output /tmp/dashboard.png http://127.0.0.1:8080/dashboard.png
```

Local acceptance evidence:

- refresh interval reported as 3600 seconds;
- refresh completed with exit code 0;
- server remained running under launchd;
- `/health` returned HTTP 200 and `ok`;
- `/dashboard.png` returned HTTP 200, `image/png`, and a 600 x 800 grayscale image;
- 26 automated Swift tests passed.

## Uninstall

```bash
./Scripts/uninstall-dashboard-automation.sh
```

Uninstall removes both LaunchAgents and the installed app/data directory. Weather cache and logs are preserved for troubleshooting.
