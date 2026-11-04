# Web UI (stage 1)

A browser view of the engine: what's playing (play / stop, panic, CPU, nodes, BPM), what Claude
Code is doing right now (prompt, thinking / reading / searching / writing / running..., activity
feed) and the engine's log.

```sh
tools/start-engine.sh --web    # the engine and the bridge, then open http://127.0.0.1:8090/
```

Or run the bridge on its own next to a running engine: `node web/server.mjs` from the repo root.
With `--web` the bridge stops when the engine does: Ctrl-C there, or `tools/stop-engine.sh`.

```
browser  <--WebSocket /ws-->  web/server.mjs  <--OSC/UDP-->  engine (57120)
                                    ^
                                    +-- /cc/event from tools/cc-hook.mjs (Claude Code hooks)
```

- `server.mjs` is plain Node (≥ 18), no dependencies. It polls `/ps/status` every 0.5 s,
  subscribes to `/ps/event/*`, and forwards a few commands from the page: pattern play/stop,
  synth play/release, panic.
- Local only: it listens on 127.0.0.1. Env: `PS_PORT` engine (57120), `PS_WEB_OSC_PORT` the
  bridge's OSC port (57130), `PS_WEB_PORT` the page (8090).
- Claude Code's activity comes from the project hooks in `.claude/settings.json`; `cc-hook.mjs`
  sends each event to both the engine (for `engine/ui2.scd`) and this bridge.
- **Focus**, shared by the page and the terminal: clicking an item, a new version of one, or
  one starting to play makes it the current item, on every open page. The bridge writes it with
  what's playing to `.run/focus.json`, and `tools/cc-context.mjs` (a `UserPromptSubmit` hook)
  adds it to each Claude Code prompt, so "this" can mean what's selected.
- **History of making:** select a pattern and the history lists every version of it and of its
  synth, in the order they were made, with the prompt for each. A step plays that pattern
  version on that synth version.
- Selecting a pattern also marks its synth (dashed), and selecting a synth marks its patterns.
- Next stages (see `docs/plan.md` notes): analysis views in WebGL.
