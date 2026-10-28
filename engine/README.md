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

A pattern file evaluates to a Pattern, e.g. `Pbind(\midinote, Pseq([50, 54, 57], inf), \dur, 0.25)`.
Its synth is the pattern's own `\instrument` if it sets one, else the synth given when defining,
else its previous binding. `/ps/pattern/play name otherSynth` rebinds it to another synth (not
allowed if the pattern sets `\instrument` itself).

The engine chains the pattern with the synth's param buses, so `/ps/param/set` and mappings
reach every note. Keys the pattern sets win over the buses. A **key check** warns when a pattern
sets a key that's neither a param of its synth nor a key the Event uses itself (`freq`, `dur`,
`legato`...), when defining the pattern, playing or rebinding it, and when its synth is redefined.

Every play/stop goes into `patterns/<name>/pairings.jsonl` with the synth and pattern version
hashes, so you can tell which versions played together and for how long.

## Control channels and mappings

Built-in channels come from the `ps_input` synth: `mouseX`, `mouseY` (0 at the bottom, 1 at the
top), `mouseButton`, and `key_<name>` (0/1) for the keys in `config.scd` (`keys: \all` by default;
key names a-z, 0-9, space). macOS may ask to allow **Input Monitoring** for scsynth before keys
report anything. Any other name is an OSC channel, created when first set or mapped. Send 0..1.

A mapping runs a `ps_mapper` synth that reads the channel and writes the param's bus:
`/ps/map warmDrone pdAmount mouseX 0 2 lin`. min/max/warp default to the param's spec. Warps:
`lin`, `exp`, `amp`, or a curve number. While a param is mapped, `/ps/param/set` still records
the value, and it applies again on `/ps/unmap`.

## Library layout

```
library/synths/<name>/synthdef.scd        current source
library/synths/<name>/meta.json           kind, params + specs, hash, last validation (engine-owned)
library/synths/<name>/info.json           caller's info (prompt, parent, tags...) for the current version
library/synths/<name>/history.jsonl       one line per new version: {"time", "hash", "info"}
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
| `/ps/pattern/play` | `name [synth]` | *reply* play (quantised to the beat), optionally rebinding. Result has key-check `warnings` |
| `/ps/pattern/stop` | `name` | |
| `/ps/pattern/set` | `name key v1 [v2 ...]` | override a key live (not saved): one value repeats, several loop, `r` = rest, `scale` takes a name, a string of pattern code works too (`"Pwhite(0.1, 0.3)"`) |
| `/ps/pattern/get` | `name` | *reply* `synth, hash, keys, overrides, playing` |
| `/ps/channel/set` | `name value` | set an OSC channel (created on first use), 0..1 |
| `/ps/channel/list` | | *reply* channels and their source (`mouse`, `key`, `osc`) |
| `/ps/map` | `synth param channel [min max] [warp]` | *reply* map a channel onto a control-rate param |
| `/ps/unmap` | `synth param` | *reply* back to the param's recorded value |
| `/ps/tempo` | `bpm` | |
| `/ps/master/amp` | `amp` | 0..2, before the limiter (ceiling -1 dBFS) |
| `/ps/panic` | | stop all patterns, free all synths |
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
