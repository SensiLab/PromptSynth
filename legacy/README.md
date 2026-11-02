# Legacy prototype

The original PromptSynth experiments (2024–2026), kept for reference. The rebuild lives in `engine/` and `library/`.

There are three separate approaches to getting SuperCollider code out of Claude. Each has its own directory and README:

| Dir | Approach | Runs in | Status (tested 2026-11-02) |
|---|---|---|---|
| [`breeding-loop/`](breeding-loop/README.md) | Python loop "breeds" synths: each reply becomes the template for the next prompt, played live over OSC into `Ndef(\synth)` | Python + sclang | Works (API side; audio side not re-tested) |
| [`anthropic-sc/`](anthropic-sc/README.md) | `Anthropic` class: full API client in sclang, with code extraction and "generate into this document" | sclang | Works |
| [`claude-api/`](claude-api/README.md) | `ClaudeAPI` class: minimal `ask` from the interpreter, text back in a callback | sclang | Works |

`sccode/` holds generated history: pieces and synths that came out of prompting (Eno, Reich, Xenakis, Moog…). They aren't part of any loop.

## Shared setup

- **API key:** `~/Library/Application Support/SuperCollider/Extensions/anthropic_key.txt`, one line. Both sclang classes read it. The Python loop reads `ANTHROPIC_API_KEY`, which you can fill from the same file (see its README). Never put a key in a source file.
- **Classes:** `Extensions/Anthropic.sc` and `Extensions/ClaudeAPI.sc` are symlinks to the files here, so edits here are what SC loads (recompile the class library after editing).
- **Model:** all three use `claude-opus-5-5`.
