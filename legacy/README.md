# Legacy prototype

The original PromptSynth loop (2024–2025), kept for reference. The rebuild lives in `engine/`, `daemon/` and `library/`.

- `code/`: Python + sclang loop. `next_sound.py` sends `prompt.sc` + the latest `template_N.sc` to the Claude API, writes the reply to `template_{N+1}.sc`, and sends `/next <path>` over OSC to `oscCommands.sc`, which interprets it into `Ndef(\synth)`.
  `Anthropic.sc` is an sclang-only API client (curl-based) that was used for experiments.
- `sccode/`: hand-prompted example synths and pieces (Moog, Eno, Reich, Xenakis…). Used as reference examples for the new synth contract.

To run the old loop: run `code/oscCommands.sc` in SuperCollider, then `python code/next_sound.py` with `ANTHROPIC_API_KEY` set.
