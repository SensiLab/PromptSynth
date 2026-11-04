#!/usr/bin/env node
// Claude Code UserPromptSubmit hook: adds the web UI's focus to each prompt, so "this" in the
// terminal can mean what's selected on the page. Reads .run/focus.json (PS_RUN_DIR), which
// web/server.mjs writes, and prints one line that Claude Code adds to the prompt's context:
//
//   [PromptSynth web UI] selected: pattern fuzzHollowSeq (on fuzzHollow) · playing: fuzzHollowSeq on fuzzHollow
//
// Prints nothing when there's no bridge (no file, or its pid has gone). Never fails: exits 0.
import fs from "node:fs";
import path from "node:path";

try {
  const root = process.env.CLAUDE_PROJECT_DIR ?? process.cwd();
  const file = path.join(process.env.PS_RUN_DIR ?? path.join(root, ".run"), "focus.json");
  const f = JSON.parse(fs.readFileSync(file, "utf8"));
  process.kill(f.pid, 0);   // throws if the bridge that wrote it has gone
  const item = (e) => e.kind === "pattern" ? `${e.name} on ${e.synth}` : `synth ${e.name}`;
  const sel = f.selected ? `selected: ${f.selected.kind} ${f.selected.name}` + (f.selected.synth ? ` (on ${f.selected.synth})` : "") : "nothing selected";
  const playing = f.playing?.length ? f.playing.map(item).join(", ") : "nothing";
  console.log(`[PromptSynth web UI] ${sel} · playing: ${playing}`);
} catch {}
process.exit(0);
