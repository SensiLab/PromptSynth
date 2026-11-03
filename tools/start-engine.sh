#!/bin/sh
# Starts the PromptSynth engine headless (no IDE): sclang loads engine/main.scd and its post
# window output prints here. Ctrl-C stops it. The engine's env vars pass through
# (PS_LIBRARY_DIR, PS_OUT_DEVICE, PS_SERVER_PORT); SCLANG overrides the sclang path.
# --views also opens the analysis views (engine/views.scd), --ui opens UI 2 (engine/ui2.scd:
# what's playing and what Claude Code is doing), once the engine is ready.
# --web also starts the web UI bridge (web/server.mjs, http://127.0.0.1:8090/); it stops with
# the engine.
root="$(cd "$(dirname "$0")/.." && pwd)"
sclang="${SCLANG:-/Applications/SuperCollider/SuperCollider.app/Contents/MacOS/sclang}"
web=0
for arg in "$@"; do
	case "$arg" in
		--views) export PS_VIEWS=1 ;;
		--ui) export PS_UI=1 ;;
		--web) web=1 ;;
		*) echo "unknown option: $arg (known: --views, --ui, --web)" >&2; exit 1 ;;
	esac
done
if [ "$web" = 1 ]; then
	node "$root/web/server.mjs" &
	webpid=$!
	trap 'kill "$webpid" 2>/dev/null' EXIT INT TERM
	"$sclang" "$root/engine/main.scd"
else
	exec "$sclang" "$root/engine/main.scd"
fi
