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
- 2026-10-29: **one main window**; analysis (scopes, spectra) in a separate window.
- 2026-10-29: the **mouse channel reads the whole screen**; the UI doesn't capture the mouse.
- 2026-10-29: **mappings are always made in code** (OSC / Claude), never in the UI.
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
- **History records topology and deliberate moves, not input.** Param sets via the API are
  recorded (settled value); mouse, LFOs, random values are not.
- **Versions are content-hashed** (sha1, first 12 hex). Returning to old source isn't stored
  twice. Performances will be hashed too, with parent links.
- **Heat map is derived** from play/stop and version changes: time per synth version × pattern
  version. No ratings, stars, "good" flags or idle detection: Steph rejected them.
- Discuss design before building; don't add scope that wasn't asked for.
