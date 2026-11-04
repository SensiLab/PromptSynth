#!/bin/sh
# Starts the PromptSynth engine headless (no IDE): sclang loads engine/main.scd and its post
# window output prints here. The engine's env vars pass through (PS_LIBRARY_DIR, PS_OUT_DEVICE,
# PS_SERVER_PORT, PS_PORT); SCLANG overrides the sclang path.
# --views also opens the analysis views (engine/views.scd), --ui opens UI 2 (engine/ui2.scd:
# what's playing and what Claude Code is doing), once the engine is ready.
# --web also starts the web UI bridge (web/server.mjs, http://127.0.0.1:8090/).
#
# Ending: Ctrl-C here, or tools/stop-engine.sh from anywhere, asks the engine to quit cleanly
# (/ps/quit: stop everything, save settings, quit scsynth, exit). A second Ctrl-C forces it.
# The session's PIDs are in .run/session.pids (PS_RUN_DIR overrides .run), the only record the
# stop script trusts; it's removed when the session ends.
root="$(cd "$(dirname "$0")/.." && pwd)"
sclang="${SCLANG:-/Applications/SuperCollider/SuperCollider.app/Contents/MacOS/sclang}"
rundir="${PS_RUN_DIR:-$root/.run}"
pidfile="$rundir/session.pids"
web=0
for arg in "$@"; do
	case "$arg" in
		--views) export PS_VIEWS=1 ;;
		--ui) export PS_UI=1 ;;
		--web) web=1 ;;
		*) echo "unknown option: $arg (known: --views, --ui, --web)" >&2; exit 1 ;;
	esac
done

mkdir -p "$rundir"
if [ -f "$pidfile" ]; then
	old=$(awk '$1 == "script" { print $2 }' "$pidfile")
	if [ -n "$old" ] && kill -0 "$old" 2>/dev/null; then
		echo "a session is already running (script pid $old); stop it first: tools/stop-engine.sh" >&2
		exit 1
	fi
	rm -f "$pidfile"   # left over from a session that didn't end cleanly
fi
echo "script $$" > "$pidfile"
export PS_PIDFILE="$pidfile"   # the engine adds "langport N" once it is ready

webpid=""
if [ "$web" = 1 ]; then
	node "$root/web/server.mjs" &
	webpid=$!
	echo "bridge $webpid" >> "$pidfile"
fi
"$sclang" "$root/engine/main.scd" &
scpid=$!
echo "sclang $scpid" >> "$pidfile"

# first Ctrl-C (or a TERM): ask the engine to quit cleanly; the next one forces it
asked=0
scsynth=""
quit() {
	[ -z "$scsynth" ] && scsynth=$(pgrep -P "$scpid" scsynth)   # now, while it's still sclang's child
	if [ "$asked" = 0 ]; then
		asked=1
		echo "[start-engine] quitting the engine (Ctrl-C again to force)" >&2
		port=$(awk '$1 == "langport" { print $2 }' "$pidfile")
		if [ -n "$port" ]; then PS_PORT="$port" node "$root/tools/psosc.mjs" /ps/quit >/dev/null 2>&1 &
		else kill "$scpid" 2>/dev/null; fi   # not ready yet: nothing to save
	else
		echo "[start-engine] forcing" >&2
		for p in $(pgrep -P "$scpid" scsynth); do kill "$p" 2>/dev/null; done
		kill "$scpid" 2>/dev/null
	fi
}
cleanup() {
	[ -n "$webpid" ] && kill "$webpid" 2>/dev/null
	# scsynth quits a moment after sclang: wait for it, so the session has really ended
	for p in $scsynth; do i=0; while kill -0 "$p" 2>/dev/null && [ $i -lt 10 ]; do sleep 0.5; i=$((i + 1)); done; done
	rm -f "$pidfile"
}
trap quit INT TERM
trap cleanup EXIT

# wait returns early when a signal arrives; keep waiting until sclang has really gone
while kill -0 "$scpid" 2>/dev/null; do wait "$scpid"; done
