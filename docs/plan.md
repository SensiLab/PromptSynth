# Plan

Status 2026-10-29. UI v1 is up ahead of phase 2 (built on what exists); phase 2 is next.

## Done

- **Phase 0:** prototype archived to `legacy/`.
- **Phase 1 + engine 0.2.0:** sclang engine over OSC. It covers:
  - validating synths and patterns, storing them in a hashed library with history and pairings
  - control channels and mappings
  - saving state
  - recording
  - 114 tests
  - `tools/psosc.mjs` CLI

  See `engine/README.md`.
- **File watching** (2026-10-28): while a synth or pattern plays, saving over its library file
  reloads it without a new version.
- **mouseY direction fixed** (2026-10-28): 0 at the bottom, 1 at the top, as documented.
- **Play fails when the server isn't running** (2026-10-29). Before, it said ok and played nothing.
- **Bar lines** (2026-10-29): play, stop and pattern swaps wait for the pattern's next bar line.
  A pattern sets its bar with `\bar` (default 4 beats); panic still stops at once.
- **No shell calls in the engine** (2026-10-29): `fileHash` computes SHA-1 in sclang (same hashes
  as `shasum`). `unixCmdGetStdOut` froze the interpreter ~1 s per call, so every define and
  watched save made playing notes late (up to 1.36 s, seen in the post window).
- **UI v1** (2026-10-29): `engine/ui.scd`, see the phase 3 entry. Engine side: `ps.log` also
  broadcasts `/ps/event/log`. 121 tests.

## Shape

```
SC UI ──(in-process)──> engine <──OSC── tools/mcp <──stdio── claude -p
  │                       │                                    ▲
  └─ prompt ──────────────┴─── unixCmd: claude -p ... ─────────┘
        progress: tools/mcp sends /ps/event/gen to the engine on each tool call
```

- **No daemon.** The engine keeps the move log, performances and heat map, since it sees every
  move. The IDE (or `sclang engine/main.scd`) runs it.
- **`tools/mcp`** is TypeScript, run by Node ≥ 23.6 with no build step. Its one dependency is
  the MCP SDK. It's also registered in `.mcp.json`, so interactive Claude Code sessions get the
  same tools.

### Generation

1. The UI sends a prompt.
2. sclang runs `claude -p --mcp-config <file> --allowedTools mcp__promptsynth ...` with a system
   prompt built from the synth contract. `claudePath` comes from `config.scd`.
3. Claude can only use the MCP tools. It defines from a source string, reads the validation
   result, fixes and redefines.
4. Each tool call reaches the UI as `/ps/event/gen`. The final reply goes to a file that sclang
   reads when the process exits. The UI can cancel it, and it times out.

Draft MCP tools:
- `synth_define(name, source, info)`, `synth_get`, `synth_play`, `synth_release`
- `param_set`
- `pattern_define`, `pattern_play`, `pattern_stop`
- `library_list`, `status`

Claude can't hear, so the numbers in the define result are its ears. The strip analysis below
can feed it more of them (spectral centroid, bands) later.

### Channel strips (routing for meters, scopes and spectra)

Every synth gets a **strip**: a private stereo bus, plus a strip synth that writes it to the mix.
Instances and that synth's pattern notes write to the strip bus instead of the mix, so a
pattern shows up on its synth's strip.

```
sources group:  instances / pattern notes ──> strip bus (per synth)
strips group:   ps_strip (per synth): level meter (SendPeakRMS ~20 Hz), gain, mute ──> mix bus
fx:             reads/writes the mix bus (master inserts, as now)
analysis:       on demand per strip or master: FFT -> freq scope / spectrum data
master group:   limiter -> out
```

- **Meters:** `ps_strip` always sends peak/RMS. The UI draws them, and they also go out as
  `/ps/event/meter` to subscribers who ask for meters (off by default: it's a stream).
- **Freq scope:** `FreqScopeView` can read any bus, so a strip's bus works once strips exist.
  One scope at a time per view, switchable between master and any strip.
- **Spectrum graphs** (later): an on-demand `ps_spectrum` synth per strip. It does FFT, then
  bands or features, then a control bus or SendReply, which the UI draws as a spectrogram or
  band history. Only runs while a view is open, so idle strips cost nothing.
- **Fx stay master inserts for now.** Per-strip inserts or sends can come later. The strip is
  where they'd go.
- **Strip gain/mute** become part of the orchestra (saved in `_state.json`, recorded as moves).
  Solo can come later.
- **Recording a single synth** becomes possible (record a strip bus), which fits "audio
  recordable as samples".

This changes node order and the `out` every instance and note gets, so it goes in **before**
the UI and the move log are built on top of it.

### Real-time visuals in the SC UI

- **Master:** scope, freq scope.
- **Strips:** a meter per strip. Later, a freq scope and spectrum graph per strip.
- **Patterns:** a flash for each pattern note.
- **History:** version timeline per synth and the heat map, both from the jsonl files.
- **Prompt:** prompt box plus a live generation log.

## Phases

1. **Phase 2: engine 0.3 + MCP + generation from the terminal.**
   - Channel strips with meters, gain and mute (engine side, tested).
   - Define from a source string.
   - `/ps/event/gen` and `/ps/event/meter`.
   - `claudePath` in config.
   - `tools/mcp` (stdio) and `.mcp.json`.
   - A `gen` entry point that runs `claude -p` the way the UI will.
   - Success test: one prompt in a terminal gives a validated, playing synth.
2. **Phase 3: SC UI v1.** Done 2026-10-29 without the parts that need phase 2:
   - Done: library list with play/stop, trail (versions and what each changed), event log with
     a clock-stall warning, master meter, analysis window with freq scope and scope.
   - Waiting for phase 2: prompt window with the generation log and cancel; strip meters with
     gain and mute.
   - Small gaps: a pending stop isn't shown (▶ stays until the bar line); the "▶ X on Y" log
     line appears at the play request, not when the pattern starts on its bar.
   - Spike first: does 30–60 fps drawing in the engine's interpreter hurt pattern timing?
     **Done 2026-10-29: no.** With hats and bass playing, clock wake-up lateness stayed at
     1–3 ms at 30 and 60 fps, 8 ms max with 2000 shapes + 200 labels per frame, ~2 ms with
     a freq scope and scope open; no `late` messages (latency is 0.2 s). The risk is blocking
     calls (shell commands, big file reads), not drawing: load files once, never per frame.
3. **Phase 4: move log and performances.**
   - `_log.jsonl` written by the engine.
   - Performance snapshot and restore (hashed, with parent links).
   - Heat map and timeline views.
4. **Phase 5: analysis views.**
   - Per-strip freq scope.
   - Spectrum graphs (`ps_spectrum`).
   - Spectral numbers in define results for Claude.
5. **Later:**
   - Recording and sample export from the UI, including per-strip.
   - Per-strip fx.
   - Solo.
   - A web UI over OSC if wanted.

## Open questions

None blocking phase 2. Notes to pick up:

- **Launching `claude -p` from sclang may stall the clock.** `unixCmdGetStdOut` blocked for
  ~0.6–1.1 s per call (measured in the sandbox). Measure `unixCmd` (async) with patterns
  playing before phase 2 relies on it; if it blocks too, launch from somewhere else.
- **A synth that compiles but fails the smoke test still reaches the server.** `runDefine`
  adds the SynthDef before the smoke test, so new notes use it. Syntax, evaluate and contract
  failures keep the old version. Affects OSC defines and watched saves.
- **Swapping to a pattern with a different bar** happens on the new pattern's bar line, so the
  old one can be cut mid-phrase.
- **Crossfade / morph between patterns** was discussed (level fade, note-by-note morph, or as
  the default on replace); nothing decided. Bar-line swaps were done instead.
- **scsynth stopped twice on 2026-10-29** with no cause found; check the post window next time.
- **Dependabot** reports 5 vulnerabilities (3 critical) on the GitHub repo; not looked into.
