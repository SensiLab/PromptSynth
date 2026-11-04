# Slides: Code as Instrument

A casual demo deck of the story in `docs/code-as-instrument.md`, with the engine built in: slides
play patterns, show library files live as they're edited, and step through the history of making.

## Setup

1. Start the engine: `tools/start-engine.sh --views`. The views windows (spectrogram, stereo field)
   are for slide 11; bring them up beside the browser. Add `--web` too if you want the web UI; they don't clash.
2. Start the slides server: `node slides/server.mjs`
3. Open http://127.0.0.1:8092/ in a browser and make it full screen.

Plain Node, no dependencies. Local only (127.0.0.1). The slides work without the engine; the live
parts wait for it (the dot bottom right turns green).

## Keys

- `→` / space / PageDown: next · `←` / PageUp: back · Home / End
- `s`: stop everything (`/ps/panic`)
- `#n` in the URL opens slide n

## Live parts

- **Play buttons:** one thing at a time; a playing button stops it. In a `data-together` bar (slide 7)
  they layer instead: starting one leaves the others playing.
- **Code panels:** the file as it is now, re-read every second. Edit it in your editor (or ask Claude
  Code) while it plays: changed lines light up, and the engine's watcher reloads the sound.
- **History of making:** pick a pattern; click a step to load that pattern version on that synth
  version (the engine's history player). "back to latest" returns to the current files.

The demo items are in `public/index.html` (`data-play`, `data-src`, and `histName` for the history slide).

## Ports

HTTP 8092 (`PS_SLIDES_PORT`), its OSC port 57132 (`PS_SLIDES_OSC_PORT`), engine 57120 (`PS_PORT`).
