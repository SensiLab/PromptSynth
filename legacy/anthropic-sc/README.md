# Anthropic.sc

A Claude API client written in sclang. Requests go out through `curl` (`unixCmd`, so they're async), and replies come back to an action function as an `AnthropicMessage`.

## Use

```supercollider
Anthropic.complete("say hello", { |r| r.getText.postln });
Anthropic.generateCode("a FM bell SynthDef", action: { |r| r.getExecutableCode(0).postln });
Anthropic.generateCode("a function that multiplies 2 numbers", action: { |r| r.executeCode(0) });
Anthropic.appendToCurrentDocument("a granular pad");        // generated code appended to the open IDE document
Anthropic.appendGeneratedCode("a kick drum SynthDef", path); // or to a file
Anthropic.chat([("role": "user", "content": "hi")], "system prompt", { |r| r.getText.postln });
```

Settings are classvars: `Anthropic.model` (`claude-opus-5-5`), `maxTokens` (1000), `temperature` (nil = not sent), `apiKey` (loaded from `Extensions/anthropic_key.txt` on first request).

Check `r.hasError` before using `r`. On error, `r` is an `AnthropicError`, which has no `getText`.

## Files

- `Anthropic.sc`: the classes (`Anthropic`, `AnthropicReq`, `AnthropicMessage`, `AnthropicError`, `AnthropicLegacy`). Symlinked into Extensions.
- `example.sc`: the calls above as blocks to evaluate in order. Start here.
- `testAPI.sc`, `testCodeExtraction.sc`: example calls to evaluate by hand.
- `debug_test.sc`: a self-running test suite (makes live API calls when evaluated).

## Known issues (not fixed)

- `getCodeBlocks` returns the whole match as well as the code. Use `getExecutableCode` / `getAllExecutableCode`.
- `debug_test.sc` has bugs in the tests themselves:
  - `testApiKey` leaves the key as `"test-key-123"` (it only restores a key that was already loaded), so every later live test gets `invalid x-api-key`.
  - `String.includes` checks for one character, not a substring, so the string and header checks fail.
  - The summary's `count(true)` counts every entry, so it always reports 100%.

## Changes 2026-11-02

- Model `claude-opus-4-6` → `claude-opus-5-5`.
- `temperature` defaults to nil and is only sent when set: newer models reject it.
- Key file read from `Platform.userExtensionDir`, not next to the class file (which is now a symlink target in the repo).
- The installed copy in Extensions was an older version that posted the curl command (key included) to the post window. It was replaced by a symlink to this file.

Tested: offline (URI, JSON encoding, text and code extraction) and live (`simpleCompletion` returned code, which interpreted to the expected value).
