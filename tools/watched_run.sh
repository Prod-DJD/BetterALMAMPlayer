#!/bin/sh
# Runs the real app and watches it, so a freeze or a memory runaway is caught
# and recorded instead of taking the Mac down.
#
#   sh tools/watched_run.sh [path/to/ALMAMPlayer.app] [seconds]
#
# Every second it writes a line to watched_run.log (next to this script's
# folder): seconds, the app's memory (MB), the Mac's free memory (MB), and
# whether the app still answers. It ends the app (and any ffmpeg it started)
# when:
#   - the app holds more than 2.5 GB,
#   - the Mac has under 1.5 GB free,
#   - the time limit passes (default 300 s).
# Send watched_run.log back: it shows what happened second by second.
APP="${1:-build/ALMAMPlayer.app}"
LIMIT="${2:-300}"
MAX_MB=2500
MIN_FREE_MB=1500
cd "$(dirname "$0")/.."
LOG="$PWD/watched_run.log"
BIN="$APP/Contents/MacOS/ALMAMPlayer"
[ -x "$BIN" ] || { echo "no app at $APP"; exit 1; }
: > "$LOG"
"$BIN" > "$PWD/watched_run.out" 2>&1 &
PID=$!
echo "started pid $PID, limit ${LIMIT}s, stop at ${MAX_MB} MB" | tee -a "$LOG"
stop() {
  echo "STOPPING: $1" | tee -a "$LOG"
  pkill -P "$PID" 2>/dev/null
  pkill -f "ALMAMPlayer.app/Contents/MacOS/ffmpeg" 2>/dev/null
  kill "$PID" 2>/dev/null
  sleep 2
  kill -9 "$PID" 2>/dev/null
  STOPPED=1
}
T=0
while kill -0 "$PID" 2>/dev/null; do
  RSS=$(ps -o rss= -p "$PID" 2>/dev/null | tr -d ' ')
  RSS=${RSS:-0}
  MB=$((RSS / 1024))
  FREE=$(vm_stat | awk '/Pages free|Pages speculative/ {gsub("\\.","",$NF); s+=$NF} END {printf "%d", s*16384/1048576}')
  WIRED=$(vm_stat | awk '/Pages wired down/ {gsub("\\.","",$NF); printf "%d", $NF*16384/1048576}')
  CPU=$(ps -o %cpu= -p "$PID" 2>/dev/null | tr -d ' ')
  echo "t=${T}s app=${MB}MB cpu=${CPU}% free=${FREE}MB wired=${WIRED}MB" >> "$LOG"
  [ "$MB" -gt "$MAX_MB" ] && stop "app memory ${MB} MB over ${MAX_MB} MB"
  [ "$FREE" -lt "$MIN_FREE_MB" ] && stop "Mac free memory ${FREE} MB under ${MIN_FREE_MB} MB"
  [ "$T" -ge "$LIMIT" ] && stop "time limit ${LIMIT}s reached"
  [ -n "$STOPPED" ] && break
  T=$((T + 1))
  sleep 1
done
echo "app ended on its own after ${T}s" | tee -a "$LOG"
# the app's own step-by-step load trace (what took the time, and the memory then)
T=$(find "$HOME/Library/Application Support" -name load_trace.log -maxdepth 4 2>/dev/null | head -1)
[ -n "$T" ] && cp "$T" "$PWD/watched_run_trace.log" && echo "copied the load trace to watched_run_trace.log"
H=$(find "$HOME/Library/Application Support" -name heartbeat.log -maxdepth 4 2>/dev/null | head -1)
[ -n "$H" ] && cp "$H" "$PWD/watched_run_heartbeat.log" && echo "copied the heartbeat to watched_run_heartbeat.log"
