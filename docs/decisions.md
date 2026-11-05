# Decisions

Settled with Steph. Change only when Steph changes them; note the date.

## Goal

A synth factory: describe a sound in a prompt, Claude writes a SuperCollider synth (and patterns),
the engine validates, plays and saves it, and every version is kept so you can go back to what
sounded good. Audio can be recorded as samples.

## Architecture (2026-10-27, revised 2026-10-28)

- **Engine** in sclang (`engine/`), controlled over OSC. The OSC API is the public contract, so
  other controllers (TouchOSC, Max, a web page) can be built on it.
- **Generation** by headless Claude Code (`claude -p`) with MCP tools, not the API: uses the
  Claude Code subscription. Don't add API-key paths unless asked.
- **SynthDef** is the main form (specs in metadata). Functions (Ndef-style textures) are wrapped.
- Each param has a control bus, so instances and pattern notes follow the same param messages.
- 2026-10-28: the **UI is in SuperCollider** (Qt), in the engine's sclang process, for real-time
  visuals. It uses only the engine's public functions and events, so it could move out later.
  A web UI is not planned (could come later over OSC).
- 2026-10-28: **no long-running daemon.** Node only runs `tools/mcp`, a stdio MCP server
  (TypeScript run directly by Node ≥ 23.6, no build step) that `claude -p` starts itself.
- 2026-10-28: **sclang starts `claude -p`** so the UI owns the process (cancel, timeout).
  `claudePath` goes in `engine/config.scd`.
- 2026-10-28: **per-synth meters** wanted, plus per-synth freq scope and spectrum graphs later.
  Every synth gets its own channel strip (submix bus) before master.
- 2026-11-01: **the terminal workflow is primary.** Steph prompts Claude Code in a terminal;
  Claude edits library files and drives the engine with `tools/psosc.mjs`. **MCP, `claude -p`
  from sclang and the UI prompt box are parked**, not dropped: pick them up only if prompting
  from the SC window without a terminal becomes wanted. The 2026-10-28 generation entries above
  describe that parked path. Steph: "enjoying the setup as is".
- 2026-11-01: **the UI is optional.** UI v1 stays as it is; no further UI work is planned unless
  Steph asks. Steph: "not even sure i need a ui".
- 2026-11-02: **speed over accuracy** in how Claude works here: the time from prompt to sound
  matters most. Steph: "i am more looking for speed more than accuracy".
- 2026-11-03: **a cheat sheet for synth and pattern work.** Sessions read `docs/cheatsheet.md`
  only; `decisions.md` and `plan.md` are for planning and engine changes. A rule change updates
  the cheat sheet too.
- 2026-11-03: **different models for different tasks**, agreed in principle; the split is open
  (see plan, "Variants and staging").
- 2026-11-03: **text-based interaction, not the GUI.** New workflow features (variants,
  staging, progress) are driven from the Claude Code terminal: project slash commands, plus a
  status line for progress. Steph: "i dont want to rely on the gui. i prefer text based
  interaction." Commands, agents and the status line live in this repo's `.claude/`, so they
  persist across sessions and only apply in this project.
- 2026-11-04: **a web UI, stage 1**, in `web/`: a local Node bridge (`web/server.mjs`, no
  dependencies, 127.0.0.1 only, started by hand) serving one page over WebSocket, OSC to the
  engine. This revisits "no long-running daemon" for the UI bridge only; the engine still needs
  none. Claude Code's activity reaches it from the project hooks via `tools/cc-hook.mjs`. The Qt
  UIs stay until the web one is as good. Steph: "yes do stage 1".
- 2026-10-29: **one main window**; analysis (scopes, spectra) in a separate window.
- 2026-10-29: the **mouse channel reads the whole screen**; the UI doesn't capture the mouse.
- 2026-10-29: **mappings are always made in code** (OSC / Claude), never in the UI.
- 2026-11-04: **a synth declares its mappings in its file** (`metadata: (map: (...))`), so they're
  versioned with it. The code wins as for defaults: a new or changed declaration is applied over
  a live mapping, a dropped one unmaps, an unchanged one leaves live changes alone. `/ps/map`
  stays for quick live tries.
- 2026-10-29: **the UI is `engine/ui.scd`**, evaluated by hand once the engine is up, not opened
  by the engine itself.
- 2026-10-29: **patterns name their synth in code** with `\instrument`, so they can't be
  rebound. To play a pattern on another synth, copy it under a new name (info records the
  parent), e.g. `glassSeq` from `warmDroneSeq`.
- 2026-10-29: **play, stop and swaps land on the pattern's bar line**; the bar length is in the
  pattern (`\bar`, default 4 beats).
- 2026-11-02: **play and stop land on the next beat**; swaps stay on the pattern's bar line.
  Steph: "play and stop seem to only occur at end of bars. they at least should be quant to beat".
- 2026-10-29: **the code is the interface.** The UI shows no params and no control channel
  values, moving or not. Steph: "i dont want to see parameters moving. the code is the
  interface and i see with my ears."

## Terms (2026-10-28)

SC's own words: "it's SC!"

| term | meaning |
|---|---|
| synth | a SynthDef in the library |
| pattern | a named pattern, bound to one synth at a time, rebindable |
| control channel | live input on a control bus: mouse, keys, OSC. Never recorded |
| mapping | channel → param with range and warp. Recorded, part of the orchestra |
| orchestra | synths (version + settings) + fx + routing + mappings + master: what it sounds like |
| performance | orchestra + patterns + what's playing: a moment to return to |
| library | everything ever saved |

## Rules

- **Never read input inside a synth.** No MouseX/MouseY/MouseButton/KeyState in a synth or fx.
  Expose a param; a control channel is mapped onto it. The engine rejects input UGens.
  Steph: "always do this. never refer to mouse inside a synth".
- **Every synth has envelope params** (2026-11-01): sustained synths `attack`, `decay`, `sustain`,
  `release`; one-shots `attack` and `decay`. fx are exempt. A layer can add its own (e.g.
  `padAttack`), but the main envelope always uses these names. Steph: "all synths should have env
  parametes. so always attack etc."
- **History records topology and deliberate moves, not input.** Param sets via the API are
  recorded (settled value); mouse, LFOs, random values are not.
- 2026-11-05: **the engine knows who edited.** Only Steph and Claude edit the files. Claude Code's
  hook logs each change its tool calls make to a synth or pattern file (`library/_edits.jsonl`);
  a change the log doesn't explain is Steph's. The history names the editor of each version and
  of the current files. Nothing before the log started (2026-11-05) is named. Steph: "the engine
  SHOULD know who made the edit. its me or you."
- 2026-11-05: **live saves skip the smoke test.** Saving over a playing file reloads it at once
  (watcher poll + compile); a define still smoke-tests. Before, each save waited ~2.5 s for the
  test. The master limiter still catches loudness; NaN would need a panic. Steph: "skip the smoke
  test on these live edits."
- **Versions are content-hashed** (sha1, first 12 hex). Returning to old source isn't stored
  twice. Performances will be hashed too, with parent links.
- **Heat map is derived** from play/stop and version changes: time per synth version × pattern
  version. No ratings, stars, "good" flags or idle detection: Steph rejected them.
- **Nothing may block the engine's interpreter** (shell commands, big file reads, per-frame
  file access): the pattern clock shares it, and a stall over the server latency (0.2 s) makes
  every playing note late. No `unixCmdGetStdOut` in the engine or UI.
- Discuss design before building; don't add scope that wasn't asked for.
- 2026-11-02: **patterns set pitch with `\note`** (or `\degree`), not `\midinote`, so `\octave` and
  `\root` work. Existing patterns were converted pitch for pitch (`\note` = midinote - 60 at the
  default octave 5).
