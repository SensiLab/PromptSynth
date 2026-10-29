# PromptSynth

Read `docs/` before planning or building: `docs/decisions.md` (settled decisions, terms, rules)
and `docs/plan.md` (current plan and open questions). Keep them up to date: record new decisions
with a date, and update the plan when a phase finishes or changes.

- Engine: `engine/` (sclang, OSC API documented in `engine/README.md`). Tests:
  `PS_SERVER_PORT=57140 PS_LIBRARY_DIR=<tmp dir> sclang engine/test/run_tests.scd`.
- Talk to a running engine with `node tools/psosc.mjs /ps/... args` (`PS_PORT` overrides 57120).
- Never put MouseX/MouseY/MouseButton/KeyState in a synth: expose a param and map a channel.
- UI: `engine/ui.scd`, evaluated in the engine's sclang once it's up.
- Never block the engine's interpreter (no `unixCmdGetStdOut`, no per-frame file reads): the
  pattern clock shares it, and stalls make notes late.
- `legacy/` is the old prototype; leave it alone unless asked.
