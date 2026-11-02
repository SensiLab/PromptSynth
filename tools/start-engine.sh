#!/bin/sh
# Starts the PromptSynth engine headless (no IDE): sclang loads engine/main.scd and its post
# window output prints here. Ctrl-C stops it. The engine's env vars pass through
# (PS_LIBRARY_DIR, PS_OUT_DEVICE, PS_SERVER_PORT); SCLANG overrides the sclang path.
# --views also opens the analysis views (engine/views.scd) once the engine is ready.
root="$(cd "$(dirname "$0")/.." && pwd)"
sclang="${SCLANG:-/Applications/SuperCollider/SuperCollider.app/Contents/MacOS/sclang}"
for arg in "$@"; do
	case "$arg" in
		--views) export PS_VIEWS=1 ;;
		*) echo "unknown option: $arg (known: --views)" >&2; exit 1 ;;
	esac
done
exec "$sclang" "$root/engine/main.scd"
