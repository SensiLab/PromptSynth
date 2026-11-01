#!/bin/sh
# Starts the PromptSynth engine headless (no IDE): sclang loads engine/main.scd and its post
# window output prints here. Ctrl-C stops it. The engine's env vars pass through
# (PS_LIBRARY_DIR, PS_OUT_DEVICE, PS_SERVER_PORT); SCLANG overrides the sclang path.
root="$(cd "$(dirname "$0")/.." && pwd)"
sclang="${SCLANG:-/Applications/SuperCollider/SuperCollider.app/Contents/MacOS/sclang}"
exec "$sclang" "$root/engine/main.scd"
