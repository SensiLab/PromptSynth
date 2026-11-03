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
import dgram from "node:dgram";
import path from "node:path";

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

let input = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (c) => { input += c; });
process.stdin.on("end", () => {
  try {
    const h = JSON.parse(input || "{}");
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
