# PromptSynth engine

sclang side of the synth factory: boots scsynth, validates and stores synths and patterns, plays
them, maps live input onto params, and records. Everything is controlled over OSC, so the daemon,
the web UI and any other controller (TouchOSC, Max, a MIDI bridge...) use the same API.

## Running

```sh
sclang engine/main.scd                          # headless (SuperCollider 3.14)
PS_LIBRARY_DIR=/some/dir sclang engine/main.scd # use another library folder
PS_OUT_DEVICE="MacBook Pro Speakers" sclang engine/main.scd
PS_SERVER_PORT=57140 sclang engine/main.scd     # own scsynth, e.g. next to an IDE server
```

Or open `engine/main.scd` in the SC IDE and evaluate it. Settings are in `engine/config.scd`.

**Sessions:** `tools/start-engine.sh [--ui] [--views] [--web]` starts the engine (and the web
bridge with `--web`) and records the session's PIDs and the engine's OSC port in
`.run/session.pids`. End it with **Ctrl-C** in that terminal or **`tools/stop-engine.sh`** from
anywhere: both send `/ps/quit` to that port, so the engine stops everything, saves its settings,
quits scsynth and exits; a second Ctrl-C, or the stop script after 8 s, stops sclang and its
scsynth by PID. A second start is refused while a session runs. Stopping sclang with a plain
signal instead leaves scsynth running (it only quits it on a normal exit).
When the engine is up it posts `[ps] ready engine=0.2.0 langPort=57120 library=...`. The port is
57121+ if 57120 was taken, for example by an open IDE. `/ps/ping` reports the engine version
and start time, so you can confirm a reload took.

Tests (silent, use a throwaway library dir and their own server):

```sh
PS_SERVER_PORT=57140 PS_LIBRARY_DIR=/tmp/ps-test-lib sclang engine/test/run_tests.scd   # exit code = failures
```

## Terms

| term | meaning |
|---|---|
| synth | a SynthDef in the library |
| pattern | a named pattern, bound to one synth at a time (can be rebound) |
| control channel | live input on a control bus: mouse, keys, or anything sent over OSC. Never recorded |
| mapping | channel → synth param, with range and warp. Part of the orchestra, saved |
| orchestra | synths + their settings + fx + mappings + master: what it sounds like |
| performance | orchestra + patterns at a moment (history comes with the daemon) |

## Synth contract

A synth file evaluates to either:

- **a SynthDef**, without `.add` / `.play`:
  - It needs an `out` arg and must write stereo with `Out.ar(out, sig)`. A fixed bus,
    `Out.kr` or more than 2 channels is rejected.
  - With a `gate` arg it is **sustained** (released with gate 0, so it must free itself
    with `doneAction: 2`). Without one it is **one-shot** and must free itself.
  - **Envelope params, always**: a sustained synth has `attack`, `decay`, `sustain` and `release`;
    a one-shot has `attack` and `decay`. fx are exempt. Not enforced by the engine.
  - Put param ranges in metadata: `SynthDef(\name, {...}, metadata: (specs: (cutoff: [100, 8000, \exp])))`.
    Missing specs are guessed from the name (freq, amp, pan, attack...) or the default value.
  - **No input inside a synth**: `MouseX`, `MouseY`, `MouseButton` and `KeyState` are rejected.
    Expose a param and map a control channel to it instead.
- **an fx SynthDef**, marked with `metadata: (fx: true, ...)`. It plays at the end of the source group,
  after every instance and pattern note, reads the mix with `In.ar(in, 2)` and writes it back,
  usually with `ReplaceOut.ar(out, dry + wet)`. The engine sets `in` and `out`. A `gate` is optional
  (fade out on release), and fx can't be played by patterns. The smoke test feeds them noise bursts.
- **a Function** (texture), like `Ndef` source: `{ |note = 42| Splay.ar(...) }`. It is wrapped
  in a gated SynthDef with `fadeIn`/`fadeOut` params, mono is duplicated and more than 2
  channels go through Splay.

The definition name is given by the caller (the name inside the file is ignored).

Validation stages, reported as `stage` on failure:

| stage | what |
|---|---|
| `name` | name must match `[A-Za-z][A-Za-z0-9_]*` and not start with `ps_` |
| `read` | file not readable |
| `syntax` | doesn't compile; details are in the post window between `[ps:log-begin:<logId>]` and `[ps:log-end:<logId>]` |
| `evaluate` | runtime error while building, or the code didn't return a SynthDef/Function (or Pattern) |
| `contract` | `out` / Out.ar / channel / no-input rules above |
| `server` | scsynth rejected it (`/fail`) |
| `smoke` | played for 2s on a private bus with default args: NaN/inf is an error. Silence, clipping, very loud output and not freeing are warnings |
| `bind` | (patterns) no synth to play, unknown synth, or an fx |

## Patterns

A pattern file evaluates to a Pattern, e.g. `Pbind(\note, Pseq([2, 6, 9], inf), \octave, 4, \dur, 0.25)`.
Pitch goes in `\note` (or `\degree`), never `\midinote`: `\midinote` skips the pitch chain, so `\octave` and
`\root` have no effect.
Its synth is the pattern's own `\instrument` if it sets one, else the synth given when defining,
else its previous binding. `/ps/pattern/play name otherSynth` rebinds it to another synth (not
allowed if the pattern sets `\instrument` itself).

**Beats and bar lines.** Play and stop happen on the next beat. Replacing a playing pattern (a
define, a watched save, a rebind, a synth redefine) happens on the pattern's next bar line, and the
replaced pattern starts from its beginning there. A pattern sets its bar length in beats with a `\bar` key, e.g.
`Pbind(..., \bar, 6)` (first event's value; the engine reads it, the synth never sees it), else 4.
Bar lines count from the clock's beat 0, so a pattern with `\bar, 6` starts on a multiple of 6
beats and its swaps land at the same place in its cycle. A stop answers at once but the pattern
keeps playing until the next beat (status still says `playing`). A play before then cancels it.
`/ps/panic` stops at once.

The engine chains the pattern with the synth's param buses, so `/ps/param/set` and mappings
reach every note. Keys the pattern sets win over the buses. A **key check** warns when a pattern
sets a key that's neither a param of its synth nor a key the Event uses itself (`freq`, `dur`,
`legato`...), when defining the pattern, playing or rebinding it, and when its synth is redefined.

Every play/stop goes into `patterns/<name>/pairings.jsonl` with the synth and pattern version
hashes, so you can tell which versions played together and for how long.

## UI

**UI 2** (`engine/ui2.scd`, opened by `tools/start-engine.sh --ui` or `PS_UI=1`, or evaluate it) is
the other side of the conversation: what's playing (patterns and synths, start / stop by button or
double-click, mute, panic, CPU and nodes), what Claude Code is doing right now (the last prompt, a
big state line: thinking, reading, searching, writing, running, web, idle, with the file or
command, and a "working m:ss" clock) with an activity feed, and the engine's log. Claude Code's
side comes from the project's hooks (`.claude/settings.json`): on every prompt, tool call and stop,
`tools/cc-hook.mjs` sends OSC `/cc/event event kind detail` to the engine's sclang port (`PS_PORT`,
default 57120), where UI 2 listens; the engine itself ignores `/cc/...`. The hooks run async and
never fail, so they don't slow Claude Code down, and nothing happens if no engine is running.

`tools/start-engine.sh --views` (or `PS_VIEWS=1`) also opens `engine/views.scd` once the engine is
ready: a scrolling mel spectrogram, live mel bands and MFCCs in one window, and a stereo field /
phase view in another, all on the hardware outs after the limiter. It needs the AnalysisViews
classes (Projects/AnalysisViews, installed by its install.scd) and FluCoMa. Evaluate the file to
open it on a running engine, or again after Cmd-period. It moves the server's default group after
the engine's master group, so the views' analysis synths read the finished output.

`engine/ui.scd` opens the UI in the engine's sclang: evaluate it once the engine is up. Evaluating
it again replaces it; it reopens itself after an engine restart and survives Cmd-period.

- **Main window:** synths and patterns (▶ when playing; a pattern shows its synth), play/stop by
  button or double-click, panic. The selected item's **trail**: its versions newest first, each
  with what it changed (the new part of its prompt), ● on the loaded one. An **event log** (newest
  first) from `/ps/event/*`, plus a warning when the pattern clock wakes more than 150 ms late (the
  interpreter was blocked). A **master meter** of the hardware outs, after the limiter.
- **Analysis window** (button): freq scope and scope of the outs.
- **History player:** the history of making the selected pairing: the pattern's and its synth's
  versions (each with its prompt) in the order they were made, oldest first; a synth on its own
  lists its versions. Click a step, or prev / next, to load and play it: old versions load in
  memory only (no new version, no history line), and the pattern swaps on its bar line. ▶ marks
  the step that's playing. **latest** puts the newest versions back with the values
  and mappings they had when the player started (closing the UI does too). While it plays,
  nothing is written to `pairings.jsonl` or `_state.json`. Steps whose version was saved over
  (the watcher reloads saves without storing them) show as not stored and are skipped.
- **Header:** CPU and node count; **mute** mutes the server's output volume (not saved).

It shows no params and no control channel values: the code is the interface. It uses the
engine's public functions and subscribes to its events. Nothing in it may block, since the
pattern clock shares the interpreter.

## Watching files

While something plays, the engine watches its library file and reloads it when you save over it:
the `pattern.scd` of each playing pattern, its synth's `synthdef.scd`, and the `synthdef.scd` of
each playing synth instance. It checks `File.mtime` every 0.5 s and reloads when the content
differs from the loaded version, through the same define path as at boot: no new version, history
line or meta (the hash in `/ps/status` and `pairings.jsonl` is that of the code it compiled), and no
smoke test, so a live edit is heard at once (a define still smoke-tests). Saves close together are all caught: mtimes are whole seconds, so while
a file was written in the last 2 s its content is compared on every tick, and after each reload
the next tick compares it again (a save made while the reload ran). If the edit doesn't compile, evaluate or pass the contract check, the previous version
keeps playing. A file edited while stopped
is picked up as soon as it plays. It all goes to the post window:

```
[ps] watch: watching synth warmDrone
[ps] watch: synth warmDrone changed, reloading
[ps] defined warmDrone (sustained, peak -17.1 dBFS)
[ps] watch: reloaded synth warmDrone (9c1e0b7f3a21)
```

## Control channels and mappings

Built-in channels come from the `ps_input` synth: `mouseX`, `mouseY` (0 at the bottom, 1 at the
top), `mouseButton`, and `key_<name>` (0/1) for the keys in `config.scd` (`keys: \all` by default;
key names a-z, 0-9, space). macOS may ask to allow **Input Monitoring** for scsynth before keys
report anything. Any other name is an OSC channel, created when first set or mapped. Send 0..1.

A mapping runs a `ps_mapper` synth that reads the channel and writes the param's bus:
`/ps/map warmDrone pdAmount mouseX 0 2 lin`. min/max/warp default to the param's spec. Warps:
`lin`, `exp`, `amp`, or a curve number. While a param is mapped, `/ps/param/set` still records
the value, and it applies again on `/ps/unmap`.

A synth can declare its mappings in its code, next to its specs:
`metadata: (specs: (...), map: (timbre: [\mouseX, 0, 1, \lin], sweep: \mouseY))` (min, max and warp
optional, as for `/ps/map`). Defining the synth applies them. As with defaults, the code wins:
a declaration that is new or changed is applied over a live mapping, one that's dropped is
unmapped, and an unchanged one leaves live `/ps/map` and `/ps/unmap` changes alone (also across
restarts: `_state.json` keeps what was declared). A bad declaration is a define warning.

## Library layout

```
library/synths/<name>/synthdef.scd        current source
library/synths/<name>/meta.json           kind, params + specs, hash, last validation (engine-owned)
library/synths/<name>/info.json           caller's info (prompt, parent, tags...) for the current version
library/synths/<name>/history.jsonl       one line per new version: {"time", "hash", "info"}
library/_edits.jsonl                      Claude Code's edits to synth and pattern files (tools/cc-hook.mjs): {time, kind, name, before, after}
library/synths/<name>/versions/<hash>.scd every version, by content hash (sha1, first 12 hex)
library/synths/<name>/recordings/
library/patterns/<name>/pattern.scd, meta.json (bound synth, keys), info.json, history.jsonl, versions/
library/patterns/<name>/pairings.jsonl    play/stop with synth + pattern hashes
library/_state.json                       orchestra settings: param values, mappings, master, tempo
library/_recordings/                      WAVs recorded without a name
library/_failed/                          failed sources + their result JSON (not in git)
```

Returning to an earlier source gives the same hash: it isn't stored twice, but the return is
logged in `history.jsonl`. All synths and patterns load at boot (without the smoke test), then
`_state.json` restores settings and mappings. Nothing starts playing on its own.

A param's value carries over to new versions, reloads and restarts, unless its default changed
in the code: then the new default is used (the code wins). `_state.json` records the defaults
values were saved under, so this holds across restarts too.

## OSC API

Send to sclang (default port 57120). Strings may be sent as OSC strings or symbols.

Results go back to the sender as `/ps/result <command> <json>`, e.g.
`/ps/result synth/define {"ok":true,"name":"pad",...}`. Commands marked *reply* always answer.
The others only answer when they fail (`"ok":false,"errors":[...]`).

| address | args | |
|---|---|---|
| `/ps/ping` | | *reply* `engine` version, `startedAt`, `langPort`, `ready` |
| `/ps/status` | | *reply* server state, tempo, recording, synths, patterns, mappings |
| `/ps/subscribe` | `[port]` | *reply* send events to sender's ip at `port` (default: sender's port) |
| `/ps/unsubscribe` | `[port]` | *reply* |
| `/ps/synth/define` | `name path [infoJson]` | *reply* validate, add, save. Result: `ok, stage, errors, warnings, kind, params, hash, peakDb, rmsDb, logId` |
| `/ps/synth/play` | `name` | start (sustained/fx: replaces the running instance) or trigger (one-shot). fx are inserted on the mix |
| `/ps/synth/release` | `name` | gate 0 (freed directly if it has no gate) |
| `/ps/param/set` | `synth key value` | set a param (clipped to its spec). Applies to the instance and pattern notes |
| `/ps/param/norm` | `synth key 0..1` | same, mapped through the spec |
| `/ps/param/get` | `synth` | *reply* `values`, `mappings`, `params` with specs, `hash` |
| `/ps/pattern/define` | `name path [synth] [infoJson]` | *reply* validate, bind, save. Result: `synth, hash, keys, warnings` |
| `/ps/pattern/default` | `name synth` | *reply* a quick pattern on `degree dur octave legato scale root` (not saved) |
| `/ps/pattern/play` | `name [synth]` | *reply* play on the next beat, optionally rebinding. Result has key-check `warnings` |
| `/ps/pattern/stop` | `name` | stop on the next beat |
| `/ps/pattern/set` | `name key v1 [v2 ...]` | override a key live (not saved): one value repeats, several loop, `r` = rest, `scale` takes a name, a string of pattern code works too (`"Pwhite(0.1, 0.3)"`) |
| `/ps/pattern/get` | `name` | *reply* `synth, hash, keys, overrides, playing` |
| `/ps/channel/set` | `name value` | set an OSC channel (created on first use), 0..1 |
| `/ps/channel/list` | | *reply* channels and their source (`mouse`, `key`, `osc`) |
| `/ps/map` | `synth param channel [min max] [warp]` | *reply* map a channel onto a control-rate param |
| `/ps/unmap` | `synth param` | *reply* back to the param's recorded value |
| `/ps/tempo` | `bpm` | |
| `/ps/master/amp` | `amp` | 0..2, before the limiter (ceiling -1 dBFS) |
| `/ps/panic` | | stop all patterns, free all synths |
| `/ps/quit` | | *reply*, then stop everything, save settings, quit scsynth and exit sclang (`tools/stop-engine.sh` uses it) |
| `/ps/history/steps` | `kind name` | *reply* the history of making: for a pattern, its versions and its synth's versions merged in time order (each step is that pattern version on that synth version); for a synth, its versions. Oldest first: `index, time, change (pattern/synth), step (the new part of its prompt), editor (Steph, Claude, Steph + Claude, or absent), pattern, patternHash, synth, synthHash, playable, current`. `edited`: who changed each current file since its latest version (`pattern`, `synth`; absent = unchanged or unknown). |
| `/ps/history/load` | `kind name index` | *reply* load that step's versions in memory (no new version, no history line) and play its pattern |
| `/ps/history/end` | | *reply* back to the latest versions, with the settings from before the player started |
| `/ps/rec/start` | `[synth or pattern] [seconds]` | *reply* `path`. Records the master output to WAV (24-bit) |
| `/ps/rec/stop` | | *reply* `path` |
| `/ps/library/reload` | | *reply* `loaded`, `failed` |

Events to subscribers:

| address | args |
|---|---|
| `/ps/event/ready` | `langPort` |
| `/ps/event/defined` | `synth\|pattern name hash` |
| `/ps/event/synth` | `name playing(0/1)` |
| `/ps/event/pattern` | `name playing(0/1) synth synthHash patternHash` (also sent when a playing pattern's synth or source changes) |
| `/ps/event/param` | `synth key value` |
| `/ps/event/map` | `synth param channel min max warp`, or `synth param ""` when unmapped |
| `/ps/event/tempo` | `bpm` |
| `/ps/event/master` | `amp` |
| `/ps/event/rec` | `recording(0/1) path` |
| `/ps/event/panic` | |
| `/ps/event/log` | `text`: every line the engine posts as `[ps] ...` (defines, failures, watcher reloads) |

## How params work

Every control-rate param of a synth gets a control bus. Instances are created with their params
mapped to those buses, and pattern notes are mapped to them too, so `/ps/param/set` (or a
mapping) changes a running instance and every pattern note, including notes already sounding.
The exceptions are pitch/time keys the pattern computes itself (`freq`, `dur`, `legato`...).
Scalar-rate (`i_`) params apply on the next note/instance and can't be mapped.

## Node order

```
default group | inputs: ps_input, mappers | sources: instances, pattern notes, fx at the tail | tests | master limiter | recorder
```

Cmd-period frees every node; the engine rebuilds this tree, the input synth and all mappings,
and its OSC API stays up.
