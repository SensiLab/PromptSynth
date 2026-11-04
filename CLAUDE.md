# PromptSynth

**Writing or changing synths and patterns:** read `docs/cheatsheet.md` only, then start. Don't read
other docs, engine code or unrelated library files first; open them only if something fails.

**Planning, or changing the engine, tools or UI:** read `docs/decisions.md` (settled decisions,
terms, rules) and `docs/plan.md` (current plan and open questions). Keep them up to date: record
new decisions with a date, and update the plan when a phase finishes or changes. When a rule
changes, update `docs/cheatsheet.md` too.

- Engine: `engine/` (sclang, OSC API documented in `engine/README.md`). Tests:
  `PS_SERVER_PORT=57140 PS_LIBRARY_DIR=<tmp dir> sclang engine/test/run_tests.scd`.
- Talk to a running engine with `node tools/psosc.mjs /ps/... args` (`PS_PORT` overrides 57120).
- Never put MouseX/MouseY/MouseButton/KeyState in a synth: expose a param and map a channel.
- UI: `engine/ui.scd`, evaluated in the engine's sclang once it's up.
- Start headless with `tools/start-engine.sh` (`--views` opens the analysis views, `engine/views.scd`;
  `--ui` opens UI 2, `engine/ui2.scd`, which shows Claude Code's activity via the hooks in `.claude/settings.json`;
  `--web` also starts the web UI bridge, `web/server.mjs`, on http://127.0.0.1:8090/).
- End a session with `tools/stop-engine.sh` (or Ctrl-C in its terminal); never stop processes by name:
  it uses only the PIDs in `.run/session.pids`. Tests: own ports, own `PS_RUN_DIR`, stop only your own PIDs.
- Never block the engine's interpreter (no `unixCmdGetStdOut`, no per-frame file reads): the
  pattern clock shares it, and stalls make notes late.
- `legacy/` is the old prototype; leave it alone unless asked.
