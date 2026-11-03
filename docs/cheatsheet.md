# Cheat sheet: synth and pattern work

Everything needed to write, define and play synths and patterns. Full detail: `engine/README.md`,
`docs/decisions.md`. Keep this in sync when a rule changes.

## Synth file: `library/synths/<name>/synthdef.scd`

Evaluates to a SynthDef (no `.add`/`.play`; the name inside is ignored):

```supercollider
SynthDef(\x, { |out = 0, gate = 1, freq = 220, amp = 0.2, pan = 0,
	attack = 0.01, decay = 0.3, sustain = 0.6, release = 1, cutoff = 2000|
	var env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
	var sig = RLPF.ar(Saw.ar(freq), cutoff, 0.3) * env * amp;
	Out.ar(out, Pan2.ar(sig, pan));
}, metadata: (specs: (cutoff: [100, 8000, \exp])))
```

- `out` arg, stereo `Out.ar(out, sig)`. No fixed bus, `Out.kr` or >2 channels.
- `gate` arg = sustained (must free itself on gate 0). No `gate` = one-shot (must free itself).
- **Envelope params always:** sustained `attack decay sustain release`; one-shot `attack decay`. fx exempt.
- **Never MouseX/MouseY/MouseButton/KeyState in a synth.** Expose a param, then `/ps/map` a channel.
- Specs in `metadata: (specs: (...))`; missing ones are guessed from the name or default.
- fx: `metadata: (fx: true)`, `In.ar(in, 2)` → `ReplaceOut.ar(out, dry + wet)`.
- Or a Function texture `{ |note = 42| ... }`: wrapped in a gated SynthDef.

## Pattern file: `library/patterns/<name>/pattern.scd`

```supercollider
Pbind(\instrument, \x, \note, Pseq([0, 3, 7, 10], inf), \octave, 4, \dur, 0.25, \bar, 4)
```

- **Pitch in `\note` (or `\degree`), never `\midinote`**, so `\octave`/`\root` work. `\note` = midinote − 60 at octave 5.
- `\instrument` names the synth (then it can't be rebound; copy the pattern to use another synth).
- `\bar` = bar length in beats (default 4): play/stop/swaps land on bar lines.
- Keys that aren't synth params or Event keys get a warning.

## Define and play (`node tools/psosc.mjs ...`, engine on 57120)

```sh
node tools/psosc.mjs /ps/synth/define x $PWD/library/synths/x/synthdef.scd '{"author":"claude-code","prompt":"...","tags":[...]}'
node tools/psosc.mjs /ps/pattern/define xSeq $PWD/library/patterns/xSeq/pattern.scd x '{"author":"claude-code","prompt":"...","tags":[...]}'
node tools/psosc.mjs /ps/pattern/play xSeq        # /ps/pattern/stop xSeq
node tools/psosc.mjs /ps/synth/play x             # /ps/synth/release x
node tools/psosc.mjs /ps/param/set x cutoff 800   # instant, no new version
node tools/psosc.mjs /ps/pattern/set xSeq dur 0.5 # live override, not saved
node tools/psosc.mjs /ps/map x cutoff mouseY 200 4000 exp
node tools/psosc.mjs /ps/status                   # /ps/panic stops everything
```

- Define result: `ok`, `stage` (name/read/syntax/evaluate/contract/server/smoke/bind), `errors`,
  `warnings`, `peakDb`. Syntax details are in the post window between `[ps:log-begin:<logId>]` markers.
- info `prompt`: on a new version, append the new ask after ` / ` to the previous prompt.
- **Saving over a playing synth or pattern reloads it** (no new version). Define to make a version.
- Fastest tweak: `/ps/param/set`. Redefine only when the structure changes.

## Rules

- Never block the engine's interpreter: no `unixCmdGetStdOut`, no per-frame file reads.
- The code is the interface: no param displays in the UI.
- A changed default in the code wins over the saved value.
- Don't touch other synths or patterns unless asked. Commit on main; push only when asked.
