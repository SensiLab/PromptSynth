# Code as Instrument: working practice

Why this project works the way it does. The working rules for synth and pattern sessions are in
`docs/cheatsheet.md`; settled decisions are in `docs/decisions.md`. This doc is the idea behind
them, and where the practice stands against the idea.

## Intent

Software is processes plus configuration, and a GUI is one lossy view of that configuration. When editing code is cheap, code itself becomes the shared interface between the human and the model. This project is live coding in SuperCollider: we make new sounds by writing code, judge them by ear, and keep every iteration as a replayable trace.

The idea places code agents in a history of how the cost of change shaped each era's interface to the machine. That cost has collapsed, so software has become softer: material you keep reshaping, not a finished artifact you configure.

## How it got here (repo history)

- **2025-03 to 2026-07, the prototype** (now `legacy/`): a prompt went to the Anthropic API, a SynthDef came back and was parsed and played from an sclang class. Later a breeding loop. The model was a generator; the human wrote prompts.
- **2026-10-27/28, the engine:** an sclang engine over OSC (`engine/`), a library of named synths and patterns, content-hashed versions, control channels and mappings.
- **2026-10-28, file watching:** saving over a playing synth or pattern reloads it. Hand edits became part of the loop.
- **2026-10-29, "the code is the interface":** the UI shows no params or channel values. Steph: "i dont want to see parameters moving. the code is the interface and i see with my ears."
- **2026-11-01, the terminal is primary:** Steph prompts Claude Code; Claude edits library files and drives the engine with `tools/psosc.mjs`. Generation through MCP and `claude -p` was parked, and the GUI became optional.
- **2026-11-02, speed over accuracy:** the time from prompt to sound matters most.
- **2026-11-04, the history of making:** a pairing's versions (pattern on synth), not a log of plays. Mappings moved into the synth file, so they are versioned with it. A web UI that follows the terminal's focus.

So the model went from generator (prototype) to collaborator in the files (now), and the GUI went from the main surface to an optional view.

## Concepts that resonate

- **The human moves from author to judge and co-author.** The human does not need to know the exact move, only to recognise whether the result is right. Hand edits are often the clearest message, so treat them as intent.
- **The model moves from tool to collaborator.** Propose moves, narrate them, and learn from the human's edits.
- **The artifact moves from product to trace.** What we keep is the history of intent, code and sound, not one final program. In the library this is each synth's and pattern's `history.jsonl` (time, hash, prompt) and `versions/<hash>.scd`.
- **The prompt is part of the trace.** Each new version appends the new ask to the previous prompt after ` / `, so a version's prompt reads as the steps that made it.
- **The deliverable is a sound, not a program.** The test is "does it sound right?", judged by ear. The smoke test is a guardrail.
- **Spec comes after, not before.** We discover the vocabulary by making things, then write it down. Do not impose a spec the human has not asked for.
- **Authorship is distributed.** The human, the model and the stored history all shape each file. Understanding lives in the whole trace.

## How it works in practice

- **One file per synth, one per pattern, edited in place:** `library/synths/<name>/synthdef.scd`, `library/patterns/<name>/pattern.scd`. Old takes are not separate files: every define stores the source as `versions/<hash>.scd` (sha1, first 12 hex), and the history player loads any of them. Returning to old source isn't stored twice.
- **Save to listen, define to keep.** Saving over a playing file reloads it with no new version. A define makes a version and a history line. Hand edits that are only saved are heard but not kept as versions.
- **One named move per step.** One prompt, one change, small enough to accept or reject as a unit.
- **State intent before the change and the outcome after.** If the outcome differs from the intent, say so plainly.
- **Re-read before continuing.** The human edits files directly. Read the current file first and never work from a stale picture.
- **Acknowledge hand edits.** Say what you think the edit means and whether it is a one-off or a principle. If unsure, ask.
- **Each synth file stands alone.** It evaluates to one SynthDef with `out`, `gate` and the envelope params; the engine provides the bus, the group, the master and the limiter.
- **Safety is in the engine, not in each synth.** The master has a limiter; mapped params are smoothed by the mapper (`lag` 0.02 s); the define path rejects input UGens (MouseX and the rest).
- **Do not consolidate or refactor across synths or patterns** unless asked. Duplication is cheap here, and reuse is by copying a file, not by importing a library.

## The file header

There is no fixed header. A synth file starts with a few comment lines that say what it is and what each added layer does (see `fmSweep`). Who made it, the prompt and the tags go in the define's info (`info.json` and the history line), not in the file.

## Synths and patterns

- A **synth** holds one SynthDef with named params. Ranges and curves are declared in `metadata: (specs: (...))`, and mappings from control channels (mouse, keys, OSC) in `metadata: (map: (...))`. Params and mappings are separate, and mappings are declarative. A new or changed declaration wins over a live mapping.
- A **pattern** is the score, in its own file. It names its synth with `\instrument`, so it can't be rebound; to play it on another synth, copy it under a new name.
- **A pattern plays its synth's current version**, not a pinned one. Editing the synth changes the sound under a playing pattern without restarting it. Which versions played together is recorded: `pairings.jsonl` logs each play and stop with both hashes, and the history of making merges the pattern's and synth's versions in time order.
- **A changed param set is not migrated.** Pattern keys that aren't synth params or Event keys get a warning on define.
- **Copying a pattern onto another synth** is the cheap way to audition a change (`glassSeq` from `warmDroneSeq`).

## Verification

- **Smoke test** on every define (not on a save-reload): the synth plays for a moment on a private bus. NaN or inf fails it; silence, clipping, a very loud RMS, or not freeing after the gate closes are warnings. The define result carries `peakDb`.
- **Analysis views** (`--views`): mel spectrogram, mel bands, MFCCs, stereo field and phase, on what you hear after the master.
- Descriptors are guardrails and a shared language, not a taste signal. The human's ear decides what is good.

## Do not

- Do not declare something good. Report what changed and let the human listen. No ratings, stars or "good" flags (Steph rejected them).
- Do not hide a move inside a bigger change.
- Do not rewrite the vocabulary without asking.
- Do not delete old versions.

## Not decided yet

- **A topology vocabulary.** Terms for synthesis structure (resonator, feedback path, excitation, formant bank) that name nodes, so moves and probes can point at what we hear. The settled terms today are the engine's (synth, pattern, control channel, mapping, orchestra, performance, library), and SC's own words. When a glossary exists it could become the schema for the declarative layer and the naming of probes.
- **Comparing a version with its predecessor** in descriptor terms ("brighter, more tonal"). Not built.
- **A static look at the graph** before playing (feedback gain above 1, unbounded modulation depth). Not built.
- **Seeded random sources** so a replay matches what was heard. Not done: patterns and synths use unseeded random values.
- **In-listening annotation** (marking a moment as a transition) and descriptor search of the library. Marking moments good or harsh would be a rating, which was rejected.

## Related ideas

- Malleable software, Ink & Switch, 2025: https://www.inkandswitch.com/essay/malleable-software/
- Software 3.0, Andrej Karpathy, 2025 (summary): https://eli5technology.blogspot.com/2025/06/software-30-andrej-karpathy.html
- Inventing on Principle, Bret Victor, 2012: https://jamesclear.com/great-speeches/inventing-on-principle-by-bret-victor
- Live coding and Algorave, TOPLAP and Alex McLean: https://esoteric.codes/blog/interview-with-alex-mclean
- Smalltalk images (live programming): https://scg.unibe.ch/download/lectures/p2-2016/P2-12-Smalltalk.pdf
- Programming as Theory Building, Peter Naur, 1985: https://notes.billmill.org/programming/academic_publishing/Peter_Naur.html
