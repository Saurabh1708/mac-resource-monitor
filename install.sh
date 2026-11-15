#!/bin/bash
# install.sh — installs mac-resource-monitor as a launchd agent that runs every 60 s and sends
# a macOS notification when CPU, memory or swap stay above a limit.
#
#   ./install.sh               install / reinstall (keeps your edited thresholds unless --reset)
#   ./install.sh --reset       reinstall and overwrite thresholds with the repo defaults
#   ./install.sh --uninstall   remove the agent, script and state
set -euo pipefail

LABEL="local.mac-resource-monitor"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
MON="$BIN_DIR/mac-resource-monitor.sh"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"

if [[ "$(uname)" != "Darwin" ]]; then
  echo "mac-resource-monitor only runs on macOS." >&2
  exit 1
fi

if [[ "${1:-}" == "--uninstall" ]]; then
  launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
  rm -f "$PLIST" "$MON"
  rm -rf "$HOME/Library/Caches/mac-resource-monitor"
  echo "Mac Resource Monitor removed (alert history kept in ~/Library/Logs/mac-resource-monitor.log)."
  exit 0
fi

mkdir -p "$BIN_DIR" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"

if [[ -f "$MON" && "${1:-}" != "--reset" ]]; then
  # Carry the user's current thresholds over into the new version of the script.
  tmp=$(mktemp)
  cp "$REPO_DIR/mac-resource-monitor.sh" "$tmp"
  for var in CPU_LIMIT MEM_FREE_MIN SWAP_LIMIT_MB SUSTAIN COOLDOWN SWAP_COOLDOWN; do
    val=$(grep -E "^${var}=" "$MON" | head -1 | cut -d= -f2 | awk '{print $1}')
    [[ -n "$val" ]] && sed -i '' -E "s/^${var}=[0-9]+/${var}=${val}/" "$tmp"
  done
  mv "$tmp" "$MON"
else
  cp "$REPO_DIR/mac-resource-monitor.sh" "$MON"
fi
chmod +x "$MON"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array><string>/bin/bash</string><string>$MON</string></array>
  <key>StartInterval</key><integer>60</integer>
  <key>RunAtLoad</key><true/>
  <key>Nice</key><integer>10</integer>
  <key>LowPriorityIO</key><true/>
  <key>StandardErrorPath</key><string>$HOME/Library/Logs/mac-resource-monitor.err.log</string>
</dict>
</plist>
EOF

launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
launchctl bootstrap "$DOMAIN" "$PLIST"

osascript -e 'display notification "Watching CPU, memory and swap every minute." with title "Mac Resource Monitor installed" sound name "Funk"'
sleep 3
echo "Mac Resource Monitor installed and running."
echo "Latest reading: $(cat "$HOME/Library/Caches/mac-resource-monitor/last" 2>/dev/null || echo 'first run in progress…')"
echo "No notification just now? System Settings → Notifications → Script Editor → Allow Notifications."
