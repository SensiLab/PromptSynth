#!/bin/sh
# Ends the session started by tools/start-engine.sh, cleanly, from any terminal. Only touches
# the PIDs in .run/session.pids (PS_RUN_DIR overrides .run): never matches processes by name.
#  1. asks the engine to quit (/ps/quit: stop everything, save settings, quit scsynth, exit)
#  2. waits up to 8 s; if sclang is still there, stops it and its scsynth by PID
#  3. stops the web bridge if there is one, and removes the PID file
root="$(cd "$(dirname "$0")/.." && pwd)"
pidfile="${PS_RUN_DIR:-$root/.run}/session.pids"
if [ ! -f "$pidfile" ]; then echo "no session running (no $pidfile)"; exit 0; fi
get() { awk -v k="$1" '$1 == k { print $2 }' "$pidfile"; }
alive() { [ -n "$1" ] && kill -0 "$1" 2>/dev/null; }
script=$(get script); sclang=$(get sclang); bridge=$(get bridge); port=$(get langport)

if alive "$sclang"; then
	scsynth=$(pgrep -P "$sclang" scsynth)   # look it up now: once sclang is gone it has no parent
	if [ -n "$port" ]; then
		echo "asking the engine (port $port) to quit"
		PS_PORT="$port" node "$root/tools/psosc.mjs" /ps/quit >/dev/null 2>&1
	fi
	i=0; while alive "$sclang" && [ $i -lt 16 ]; do sleep 0.5; i=$((i + 1)); done
	if alive "$sclang"; then
		echo "the engine didn't quit; stopping sclang ($sclang) and scsynth (${scsynth:-none})"
		kill "$sclang" 2>/dev/null
	fi
	for p in $scsynth; do alive "$p" && kill "$p" 2>/dev/null; done
fi
alive "$bridge" && { echo "stopping the web bridge ($bridge)"; kill "$bridge" 2>/dev/null; }
i=0; while alive "$script" && [ $i -lt 6 ]; do sleep 0.5; i=$((i + 1)); done
rm -f "$pidfile"
left=""
for p in $script $sclang $bridge $scsynth; do alive "$p" && left="$left $p"; done
if [ -n "$left" ]; then echo "still running:$left" >&2; exit 1; fi
echo "session ended"
