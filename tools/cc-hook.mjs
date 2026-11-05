#!/usr/bin/env node
// Claude Code hook: tells the PromptSynth UIs what Claude Code is doing. Reads the hook's JSON
// from stdin and sends one OSC message, fire and forget, to the engine's sclang (PS_PORT, default
// 57120), where engine/ui2.scd listens, and to the web UI bridge (PS_WEB_OSC_PORT, default 57130,
// web/server.mjs):
//
//   /cc/event  event kind detail
//
//   event   the hook event (UserPromptSubmit, PreToolUse, PostToolUse, PostToolUseFailure, Stop)
//   kind    prompt | reading | searching | writing | running | web | agent | skill | tool |
//           done | failed | idle
//   detail  the prompt text, a file, a pattern, a command's description... (short)
//
// The engine itself ignores /cc/... (it only answers /ps/...). Never fails: a hook error must not
// get in Claude Code's way, so every problem exits 0 quietly.
//
// Who edited: around each tool call that can write files (Edit, Write, NotebookEdit, Bash), the
// hook hashes every synth and pattern file before (PreToolUse, kept in PS_RUN_DIR) and after
// (PostToolUse), and appends what changed to library/_edits.jsonl as Claude's edit. A change the
// log doesn't explain is Steph's (engine/lib/history.scd, editorOf).
import dgram from "node:dgram";
import path from "node:path";
import fs from "node:fs";
import crypto from "node:crypto";

const ports = [Number(process.env.PS_PORT ?? 57120), Number(process.env.PS_WEB_OSC_PORT ?? 57130)];
const root = process.env.CLAUDE_PROJECT_DIR ?? process.cwd();

const pad4 = (buf) => Buffer.concat([buf, Buffer.alloc(4 - (buf.length % 4))]);
const oscString = (s) => pad4(Buffer.from(s, "utf8"));
const encode = (addr, args) =>
  Buffer.concat([oscString(addr), oscString("," + "s".repeat(args.length)), ...args.map(oscString)]);

const short = (s, n = 140) => {
  const t = String(s ?? "").replace(/\s+/g, " ").trim();
  return t.length > n ? t.slice(0, n - 1) + "…" : t;
};
const rel = (p) => (p ? short(path.relative(root, p) || p, 100) : "");

const kinds = {
  Read: "reading", Grep: "searching", Glob: "searching", Edit: "writing", Write: "writing",
  NotebookEdit: "writing", Bash: "running", WebSearch: "web", WebFetch: "web",
  Agent: "agent", Task: "agent", Skill: "skill",
};

function describe(h) {
  const e = h.hook_event_name ?? "";
  const t = h.tool_name ?? "";
  const i = h.tool_input ?? {};
  switch (e) {
    case "UserPromptSubmit": return ["prompt", short(h.prompt, 300)];
    case "Stop": return ["idle", ""];
    case "PostToolUse": return ["done", t];
    case "PostToolUseFailure": return ["failed", t];
    case "PreToolUse": {
      const kind = kinds[t] ?? "tool";
      const detail =
        i.file_path ? rel(i.file_path)
        : i.pattern ? short(i.pattern, 80) + (i.path ? "  in " + rel(i.path) : "")
        : i.description ? short(i.description)
        : i.command ? short(i.command, 100)
        : i.query ? short(i.query)
        : i.url ? short(i.url)
        : i.skill ? short(i.skill)
        : t;
      return [kind, detail];
    }
    default: return ["tool", e];
  }
}

// --- who edited: hashes of the library's synth and pattern files ---
const writers = new Set(["Edit", "Write", "NotebookEdit", "MultiEdit", "Bash"]);
const libDir = process.env.PS_LIBRARY_DIR ?? path.join(root, "library");
const runDir = process.env.PS_RUN_DIR ?? path.join(root, ".run");
const pad2 = (n) => String(n).padStart(2, "0");
const isoNow = () => { const d = new Date(); return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}T${pad2(d.getHours())}:${pad2(d.getMinutes())}:${pad2(d.getSeconds())}`; };
function libraryHashes() {
  const out = {};
  for (const [kind, sub, file] of [["synth", "synths", "synthdef.scd"], ["pattern", "patterns", "pattern.scd"]]) {
    let names = [];
    try { names = fs.readdirSync(path.join(libDir, sub)); } catch {}
    for (const name of names) {
      try { out[`${kind} ${name}`] = crypto.createHash("sha1").update(fs.readFileSync(path.join(libDir, sub, name, file))).digest("hex").slice(0, 12); } catch {}
    }
  }
  return out;
}
function trackEdits(h) {
  if (!writers.has(h.tool_name) || !h.tool_use_id || !/^[\w-]+$/.test(h.tool_use_id)) return;
  const snap = path.join(runDir, `cc-before-${h.tool_use_id}.json`);
  if (h.hook_event_name === "PreToolUse") {
    fs.mkdirSync(runDir, { recursive: true });
    fs.writeFileSync(snap, JSON.stringify(libraryHashes()));
  } else if (h.hook_event_name === "PostToolUse" || h.hook_event_name === "PostToolUseFailure") {
    let before;
    try { before = JSON.parse(fs.readFileSync(snap, "utf8")); } catch { return; }
    fs.rmSync(snap, { force: true });
    const after = libraryHashes(), time = isoNow(), log = path.join(libDir, "_edits.jsonl");
    const lines = [];
    if (!fs.existsSync(log)) lines.push({ time, start: true });
    for (const key of new Set([...Object.keys(before), ...Object.keys(after)])) {
      if (before[key] === after[key] || !after[key]) continue;
      const [kind, name] = key.split(" ");
      lines.push({ time, kind, name, before: before[key] ?? "", after: after[key], editor: "claude" });
    }
    if (lines.length) fs.appendFileSync(log, lines.map((l) => JSON.stringify(l) + "\n").join(""));
  }
}

let input = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (c) => { input += c; });
process.stdin.on("end", () => {
  try {
    const h = JSON.parse(input || "{}");
    try { trackEdits(h); } catch {}
    const [kind, detail] = describe(h);
    const sock = dgram.createSocket("udp4");
    const msg = encode("/cc/event", [h.hook_event_name ?? "", kind, detail]);
    let left = ports.length;
    for (const port of ports) {
      sock.send(msg, port, "127.0.0.1", () => { if (--left === 0) { sock.close(); process.exit(0); } });
    }
    setTimeout(() => process.exit(0), 500).unref();
  } catch {
    process.exit(0);
  }
});
