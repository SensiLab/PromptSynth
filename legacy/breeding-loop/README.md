# Breeding loop

A Python script that "breeds" synths. Each round, `next_sound.py` sends Claude `prompt.sc` plus the latest `template_N.sc`, saves the code from the reply as `template_{N+1}.sc`, and sends `/next <path>` over OSC to sclang, which interprets it into `Ndef(\synth)` (crossfading over 4 s). The new file is the template for the next round, so the sound drifts by variation.

## Files

- `next_sound.py`: the loop. Settings at the top: `count = 4` rounds, `secsPerSynth = 10`, OSC to `127.0.0.1:57120`.
- `oscCommands.sc`: run in SC first. Boots the server and listens for `/start` (play the Ndef), `/next <path>` (interpret file), `/end` (fade out, quit server).
- `prompt.sc`: the prompt. Only the uncommented block at the top is sent; the commented blocks below are earlier prompts.
- `template_0.sc`: the seed. Generated `template_1.sc`… are gitignored.
- `requirements.txt`: Python packages (frozen 2026-11-02).

## Run

```sh
cd legacy/breeding-loop
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt   # once
# in SC: evaluate oscCommands.sc, wait for the server to boot
ANTHROPIC_API_KEY=$(cat ~/Library/Application\ Support/SuperCollider/Extensions/anthropic_key.txt) .venv/bin/python next_sound.py
```

Port 57120 is sclang's default, which the PromptSynth engine also uses. Don't run this with the engine up: `/start`, `/next` and `/end` would go to it.

## Notes

- `oscCommands.sc` picks the output device `"Built-in Output"`. If that device name doesn't exist on the machine, booting fails. The commented lines show other devices used.
- The prompt asks for single-line code under 512 chars, which the model follows.

## Changes 2026-11-02

- Model `claude-3-5-sonnet-20241022` (retired) → `claude-opus-5-5`.
- Removed `temperature=1`: newer models reject `temperature`.
- `max_tokens` 1004 → 16000: the model thinks before answering and can't turn thinking off, so 1004 ran out before any code was written.
- Reply text: takes the first text block instead of `content[0]` (now a thinking block).
- `requirements.txt` refrozen: the old pins (pydantic-core 2.27) don't build on Python 3.14.

Tested: a full 4-round run against a stand-in OSC listener (`/start`, 4× `/next`, `/end` all arrived), and all 4 generated templates compile in sclang. Not tested: playing them through `oscCommands.sc` (needs ears).
