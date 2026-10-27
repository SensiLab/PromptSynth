# PromptSynth engine

sclang side of the synth factory: boots scsynth, validates and stores synths, plays them as
single instances or patterns, and records. Everything is controlled over OSC, so the daemon,
the web UI and any other controller (TouchOSC, Max, a MIDI bridge...) use the same API.

## Running

```sh
sclang engine/main.scd                          # headless (SuperCollider 3.14)
PS_LIBRARY_DIR=/some/dir sclang engine/main.scd # use another library folder
PS_OUT_DEVICE="MacBook Pro Speakers" sclang engine/main.scd
PS_SERVER_PORT=57140 sclang engine/main.scd  # own scsynth, e.g. next to an IDE server
```

Or open `engine/main.scd` in the SC IDE and evaluate it. Settings are in `engine/config.scd`.
When the engine is up it posts `[ps] ready langPort=57120 library=...`. The port is 57121+
if 57120 was taken, for example by an open IDE.

Tests (silent, use a throwaway library dir):

```sh
PS_SERVER_PORT=57140 PS_LIBRARY_DIR=/tmp/ps-test-lib sclang engine/test/run_tests.scd   # exit code = failures
```

## Synth contract

A synth file evaluates to either:

- **a SynthDef**, without `.add` / `.play`:
  - It needs an `out` arg and must write stereo with `Out.ar(out, sig)`. A fixed bus,
    `Out.kr` or more than 2 channels is rejected.
  - With a `gate` arg it is **sustained** (released with gate 0, so it must free itself
    with `doneAction: 2`). Without one it is **one-shot** and must free itself.
  - Put param ranges in metadata: `SynthDef(\name, {...}, metadata: (specs: (cutoff: [100, 8000, \exp])))`.
    Missing specs are guessed from the name (freq, amp, pan, attack...) or the default value.
- **an fx SynthDef**, marked with `metadata: (fx: true, ...)`. It plays at the end of the source group,
  after every instance and pattern note, reads the mix with `In.ar(in, 2)` and writes it back,
  usually with `ReplaceOut.ar(out, dry + wet)`. The engine sets `in` and `out`. A `gate` is optional
  (fade out on release), and fx can't play patterns. The smoke test feeds them noise bursts.
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
| `evaluate` | runtime error while building, or the code didn't return a SynthDef/Function |
| `contract` | `out` / Out.ar / channel rules above |
| `server` | scsynth rejected it (`/fail`) |
| `smoke` | played for 2s on a private bus with default args: NaN/inf is an error. Silence, clipping, very loud output and not freeing are warnings |

## Library layout

```
library/<name>/synthdef.scd    source
library/<name>/meta.json       kind, params + specs, last validation (written by the engine)
library/<name>/info.json       caller's info JSON (prompt, parent, tags...), stored verbatim
library/<name>/pattern.scd     optional pattern
library/<name>/versions/       previous synthdef/pattern sources
library/<name>/recordings/     WAVs recorded with this synth's name
library/_recordings/           WAVs recorded without a name
library/_failed/               failed sources + their result JSON
```

All synths are loaded at boot (without the smoke test).

## OSC API

Send to sclang (default port 57120). Strings may be sent as OSC strings or symbols.

Results go back to the sender as `/ps/result <command> <json>`, e.g.
`/ps/result synth/define {"ok":true,"name":"pad",...}`. Commands marked *reply* always answer.
The others only answer when they fail (`"ok":false,"errors":[...]`).

| address | args | |
|---|---|---|
| `/ps/ping` | | *reply* `version`, `langPort`, `ready` |
| `/ps/status` | | *reply* server state, tempo, recording, synths with `playing`/`pattern` |
| `/ps/subscribe` | `[port]` | *reply* send events to sender's ip at `port` (default: sender's port) |
| `/ps/unsubscribe` | `[port]` | *reply* |
| `/ps/synth/define` | `name path [infoJson]` | *reply* validate the file, add it, save it to the library. The result has `ok, stage, errors, warnings, kind, params, peakDb, rmsDb, logId` |
| `/ps/synth/play` | `name` | start (sustained/fx: replaces the running instance) or trigger (one-shot). fx are inserted on the mix |
| `/ps/synth/release` | `name` | gate 0 (freed directly if it has no gate) |
| `/ps/param/set` | `name key value` | set a param (clipped to its spec). Applies to the instance and pattern events |
| `/ps/param/norm` | `name key 0..1` | same, mapped through the spec. Use this for faders |
| `/ps/param/get` | `name` | *reply* `values`, `params` with specs |
| `/ps/pattern/play` | `name` | play the synth's pattern (quantised to the beat) |
| `/ps/pattern/stop` | `name` | |
| `/ps/pattern/set` | `name key v1 [v2 ...]` | one value repeats, several loop. `r` = rest, `scale` takes a name (`minor`, `dorian`...), a string with pattern code works too (`"Pwhite(0.1, 0.3)"`). The default pattern has `degree dur octave legato scale root` |
| `/ps/pattern/define` | `name path` | *reply* file evaluates to a Pattern (e.g. `Pbind(...)`). The engine adds `\instrument`, output and param buses. Keys it sets override the bus values |
| `/ps/tempo` | `bpm` | |
| `/ps/master/amp` | `amp` | 0..2, before the limiter (ceiling -1 dBFS) |
| `/ps/panic` | | stop all patterns, free all synths |
| `/ps/rec/start` | `[name] [seconds]` | *reply* `path`. Records the master output to WAV (24-bit) |
| `/ps/rec/stop` | | *reply* `path` |
| `/ps/library/reload` | | *reply* `loaded`, `failed` |

Events to subscribers:

| address | args |
|---|---|
| `/ps/event/ready` | `langPort` |
| `/ps/event/defined` | `name` |
| `/ps/event/synth` | `name playing(0/1)` |
| `/ps/event/pattern` | `name playing(0/1)` |
| `/ps/event/param` | `name key value` |
| `/ps/event/tempo` | `bpm` |
| `/ps/event/master` | `amp` |
| `/ps/event/rec` | `recording(0/1) path` |
| `/ps/event/panic` | |

## How params work

Every control-rate param of a synth gets a control bus. Instances are created with their params
mapped to those buses, and pattern events are mapped to them too, so `/ps/param/set` changes a
running instance and every pattern note. The exceptions are pitch/time keys the pattern computes
itself (`freq`, `dur`, `legato`...). Scalar-rate (`i_`) params apply on the next note/instance.
