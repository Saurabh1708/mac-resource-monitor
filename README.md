# Mac Resource Monitor

A tiny, dependency-free macOS monitor that sends you a notification when **CPU**, **memory** or **swap** stay above a limit, and tells you which processes are responsible.

```
CPU at 92% for 3+ min
Top: mds_stores 60.8%  com.docker.backend 24.1%  WindowServer 12.0%
```

It's a single bash script run by `launchd` every 60 seconds. It uses only built-in tools (`top`, `ps`, `sysctl`, `memory_pressure`, `osascript`), with no Homebrew, no daemon and no menu-bar app.

## Why

Older Macs (especially Intel MacBook Pros running Docker Desktop) slow down quietly: Spotlight starts reindexing `node_modules`, a forgotten database keeps running, swap creeps up to several GB. By the time you notice the lag, you don't know what caused it. It tells you while it's happening.

## Install

```bash
git clone https://github.com/Saurabh1708/mac-resource-monitor.git
cd mac-resource-monitor
./install.sh
```

You should get a "Mac Resource Monitor installed" notification. If you don't, enable notifications for **Script Editor** in *System Settings → Notifications* (macOS shows script notifications under that name).

## Default alerts

| Check  | Alerts when                                   | Repeats at most |
|--------|-----------------------------------------------|-----------------|
| CPU    | total CPU > **85%** for 3 consecutive minutes | every 15 min    |
| Memory | free memory < **20%** for 3 consecutive minutes | every 15 min  |
| Swap   | swap used > **2 GB** for 3 consecutive minutes | every 4 h (swap only shrinks on restart) |

Requiring several consecutive checks means short spikes (a build, a page load) don't set it off.

## Configuration

Edit the variables at the top of `~/.local/bin/mac-resource-monitor.sh`. Changes apply on the next run, with no restart needed.

```bash
CPU_LIMIT=85          # % of total CPU busy
MEM_FREE_MIN=20       # % memory free; below this = alert
SWAP_LIMIT_MB=2048    # swap in use, MB
SUSTAIN=3             # consecutive checks (minutes) over the limit before alerting
COOLDOWN=900          # seconds before the same CPU/memory alert can repeat
SWAP_COOLDOWN=14400   # seconds before the swap alert can repeat
```

Re-running `./install.sh` after a `git pull` keeps your edited thresholds. Use `./install.sh --reset` to go back to the defaults.

## Useful commands

```bash
cat ~/Library/Caches/mac-resource-monitor/last      # latest reading
cat ~/Library/Logs/mac-resource-monitor.log         # alert history
launchctl print gui/$(id -u)/local.mac-resource-monitor | head -20   # agent status
./install.sh --uninstall              # remove everything
```

## Overhead

Each run takes about one second (`top` needs two samples to compute CPU usage) and runs at `Nice 10` with low-priority I/O.

## Files

| Path | Purpose |
|------|---------|
| `~/.local/bin/mac-resource-monitor.sh` | the monitor script |
| `~/Library/LaunchAgents/local.mac-resource-monitor.plist` | launchd agent, runs every 60 s |
| `~/Library/Caches/mac-resource-monitor/` | per-check counters and the latest reading |
| `~/Library/Logs/mac-resource-monitor.log` | alert history |

## License

MIT
