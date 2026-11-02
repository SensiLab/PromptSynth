# ClaudeAPI.sc

The minimal way to prompt Claude from the interpreter: one `ask` method, text back in a callback.

```supercollider
c = ClaudeAPI.new;   // key from Extensions/anthropic_key.txt; or ClaudeAPI.new("sk-...")
c.ask("a one-line SuperCollider drone", { |text| text.postln }, { |err| err.postln });
c.ask("a one-line Ndef(\\synth) drone, code only, no fences", { |text| text.interpret });
```

`example.sc` has these as blocks to evaluate in order.

Model `claude-opus-5-5`, `max_tokens` 4096. Request and response go through JSON files in `Platform.userAppSupportDir/tmp`, which are deleted after a reply.

## History

Written 2025-03-31 to 2025-04-01 ("basic class working", commit `55be750`). Commit `2e255a7` ("bad code") deleted it. After that, only a stub holding a hardcoded API key existed, in Extensions and as an untracked file here. On 2026-11-02 the class was restored from `55be750` and the stub removed.

## Changes 2026-11-02

- Key read from `Extensions/anthropic_key.txt` when none is passed.
- Model `claude-3-7-sonnet-20250219` (retired) → `claude-opus-5-5`.
- Response parsing uses String keys (`parsed["content"]`): sclang's `parseJSON` returns a Dictionary with String keys, so the old Symbol lookups (`parsed['content']`) always got nil and every call failed with "Invalid response format".

Note: the key is passed to `curl` on the command line, so it's visible in the process list while a request runs. `Anthropic.sc` uses a header file instead.

Tested live: `ask` returned the expected text.
