#!/bin/bash
# mac-resource-monitor.sh — Mac Resource Monitor, run every 60 s by launchd (local.mac-resource-monitor).
# Installed to ~/.local/bin/mac-resource-monitor.sh by install.sh. Edit thresholds below.

CPU_LIMIT=85          # % of total CPU busy
MEM_FREE_MIN=20       # % memory free (memory_pressure); below this = alert
SWAP_LIMIT_MB=2048    # swap in use, MB
SUSTAIN=3             # consecutive checks (minutes) over the limit before alerting
COOLDOWN=900          # seconds before the same CPU/memory alert can repeat (15 min)
SWAP_COOLDOWN=14400   # swap only shrinks on reboot, so repeat at most every 4 h

export PATH=/usr/bin:/bin:/usr/sbin:/sbin
STATE="$HOME/Library/Caches/mac-resource-monitor"; mkdir -p "$STATE"
LOG="$HOME/Library/Logs/mac-resource-monitor.log"
now=$(date +%s)

# ---- measurements
idle=$(top -l 2 -n 0 -s 1 | awk '/CPU usage/ {v=$7} END {gsub("%","",v); print v}')
cpu=$(awk -v i="${idle:-100}" 'BEGIN {printf "%d", 100 - i}')

memfree=$(memory_pressure -Q 2>/dev/null | awk -F': ' '/free percentage/ {gsub("%","",$2); print $2}')
memfree=${memfree:-100}

swap=$(sysctl -n vm.swapusage | awk '{
  for (i = 1; i <= NF; i++) if ($i == "used") {
    v = $(i + 2); mult = (v ~ /G$/) ? 1024 : 1; gsub(/[MG]/, "", v); printf "%d", v * mult
  }}')
swap=${swap:-0}

top_cpu()  { ps -Aceo pcpu=,comm= -r | head -3 | awk '{p=$1; $1=""; sub(/^ /,""); printf "%s %s%%  ", $0, p}'; }
top_mem()  { ps -Aceo rss=,comm= -m | head -3 | awk '{m=$1; $1=""; sub(/^ /,""); printf "%s %.1fGB  ", $0, m/1048576}'; }

notify() { # title, message
  osascript - "$1" "$2" >/dev/null 2>&1 <<'AS'
on run argv
  display notification (item 2 of argv) with title (item 1 of argv) sound name "Funk"
end run
AS
  echo "$(date '+%F %T')  $1 — $2" >> "$LOG"
}

# check NAME OVER(0/1) COOLDOWN TITLE MESSAGE
check() {
  local f="$STATE/$1" count=0 last=0
  [[ -f "$f" ]] && read -r count last < "$f"
  if (( $2 )); then count=$((count + 1)); else count=0; fi
  if (( count >= SUSTAIN && now - last >= $3 )); then
    notify "$4" "$5"
    last=$now
  fi
  echo "$count $last" > "$f"
}

check cpu  "$(( cpu > CPU_LIMIT ))"          "$COOLDOWN" \
  "CPU at ${cpu}% for ${SUSTAIN}+ min" "Top: $(top_cpu)"
check mem  "$(( memfree < MEM_FREE_MIN ))"   "$COOLDOWN" \
  "Memory low: ${memfree}% free" "Top: $(top_mem)"
check swap "$(( swap > SWAP_LIMIT_MB ))"     "$SWAP_COOLDOWN" \
  "Swap at $((swap / 1024)).$(( (swap % 1024) * 10 / 1024 )) GB" "Top: $(top_mem)— restart clears swap"

echo "$(date '+%F %T') cpu=${cpu}% memfree=${memfree}% swap=${swap}MB" > "$STATE/last"
