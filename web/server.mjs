#!/usr/bin/env node
// PromptSynth web UI bridge (stage 1). Serves web/public/ on http://127.0.0.1:8090 and relays
// between the browser (a WebSocket at /ws) and the engine (OSC over UDP):
//
//   engine -> browser  /ps/status every 0.5 s, every /ps/event/* (log, pattern, synth, defined,
//                      panic), and Claude Code's /cc/event from tools/cc-hook.mjs
//   browser -> engine  a few commands: pattern play/stop, synth play/release, panic, and solo
//                      (stop everything else, then play the selection: one thing at a time)
//   history            history/steps, history/load, history/end -> the engine's history player
//   trail              the selected item's versions and what each prompt changed, read from
//                      the library's history.jsonl / info.json (no engine involved)
//   focus              the current item, shared by every page and the terminal: set by a click
//                      (select), a new version, or something starting to play. Written with
//                      what's playing to .run/focus.json (PS_RUN_DIR), which tools/cc-context.mjs
//                      adds to each Claude Code prompt; removed when the bridge stops.
//
// Plain Node, no dependencies (the WebSocket is the minimum of RFC 6455 for one local page).
// Local only: it listens on 127.0.0.1. Env: PS_PORT engine port (57120), PS_WEB_OSC_PORT this
// bridge's OSC port (57130, where the engine's events and cc-hook arrive), PS_WEB_PORT (8090).
import dgram from "node:dgram";
import http from "node:http";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const enginePort = Number(process.env.PS_PORT ?? 57120);
const oscPort = Number(process.env.PS_WEB_OSC_PORT ?? 57130);
const httpPort = Number(process.env.PS_WEB_PORT ?? 8090);
const publicDir = path.join(path.dirname(fileURLToPath(import.meta.url)), "public");
const runDir = process.env.PS_RUN_DIR ?? path.join(path.dirname(fileURLToPath(import.meta.url)), "..", ".run");
const focusFile = path.join(runDir, "focus.json");

// --- OSC (strings, floats, ints) ---
const pad4 = (buf) => Buffer.concat([buf, Buffer.alloc(4 - (buf.length % 4))]);
const oscString = (s) => pad4(Buffer.from(String(s), "utf8"));
function encode(addr, args) {
  let tags = ",";
  const parts = [];
  for (const a of args) {
    if (typeof a === "number" && Number.isInteger(a)) { tags += "i"; const b = Buffer.alloc(4); b.writeInt32BE(a); parts.push(b); }
    else if (typeof a === "number") { tags += "f"; const b = Buffer.alloc(4); b.writeFloatBE(a); parts.push(b); }
    else { tags += "s"; parts.push(oscString(a)); }
  }
  return Buffer.concat([oscString(addr), oscString(tags), ...parts]);
}
function decode(buf) {
  let off = 0;
  const str = () => { const end = buf.indexOf(0, off); const s = buf.toString("utf8", off, end); off = (end + 4) & ~3; return s; };
  const addr = str();
  const tags = str().slice(1);
  const args = [];
  for (const t of tags) {
    if (t === "s") args.push(str());
    else if (t === "i") { args.push(buf.readInt32BE(off)); off += 4; }
    else if (t === "f") { args.push(buf.readFloatBE(off)); off += 4; }
    else break;
  }
  return { addr, args };
}

const osc = dgram.createSocket("udp4");
const toEngine = (addr, args = []) => osc.send(encode(addr, args), enginePort, "127.0.0.1");

// --- WebSocket (server side only: text frames, ping/pong, close) ---
const clients = new Set();
function wsSend(sock, text) {
  const data = Buffer.from(text, "utf8");
  const head = data.length < 126 ? Buffer.from([0x81, data.length])
    : data.length < 65536 ? Buffer.from([0x81, 126, data.length >> 8, data.length & 255])
    : (() => { const h = Buffer.alloc(10); h[0] = 0x81; h[1] = 127; h.writeBigUInt64BE(BigInt(data.length), 2); return h; })();
  try { sock.write(Buffer.concat([head, data])); } catch { clients.delete(sock); }
}
const broadcast = (obj) => { const t = JSON.stringify(obj); for (const c of clients) wsSend(c, t); };

function wsFrames(sock, onText) {
  let buf = Buffer.alloc(0);
  sock.on("data", (chunk) => {
    buf = Buffer.concat([buf, chunk]);
    while (buf.length >= 2) {
      const op = buf[0] & 15, masked = buf[1] & 128;
      let len = buf[1] & 127, off = 2;
      if (len === 126) { if (buf.length < 4) return; len = buf.readUInt16BE(2); off = 4; }
      else if (len === 127) { if (buf.length < 10) return; len = Number(buf.readBigUInt64BE(2)); off = 10; }
      const mask = masked ? buf.subarray(off, off + 4) : null;
      if (masked) off += 4;
      if (buf.length < off + len) return;
      const payload = Buffer.from(buf.subarray(off, off + len));
      if (mask) for (let i = 0; i < payload.length; i++) payload[i] ^= mask[i & 3];
      buf = buf.subarray(off + len);
      if (op === 1) onText(payload.toString("utf8"));
      else if (op === 8) { try { sock.end(Buffer.from([0x88, 0])); } catch {} clients.delete(sock); }
      else if (op === 9) { try { sock.write(Buffer.concat([Buffer.from([0x8a, payload.length]), payload])); } catch {} }
    }
  });
}

// --- the selected item's trail, as in engine/ui.scd: newest first, each version's new prompt step ---
function trail(kind, name) {
  if (!lastStatus || !/^[A-Za-z][A-Za-z0-9_]*$/.test(name)) return null;
  const dir = path.join(lastStatus.libraryDir, kind === "synth" ? "synths" : "patterns", name);
  const entry = (kind === "synth" ? lastStatus.synths : lastStatus.patterns).find((e) => e.name === name);
  const loaded = entry?.hash;
  let lines = [];
  try {
    lines = fs.readFileSync(path.join(dir, "history.jsonl"), "utf8").split("\n").filter(Boolean)
      .map((l) => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean);
  } catch {}
  const lastStep = (p) => { const i = p.lastIndexOf(" / "); return i < 0 ? p : p.slice(i + 3); };
  let prev = null, seen = false;
  const out = [];
  for (const h of lines) {
    const prompt = h.info && typeof h.info === "object" ? h.info.prompt : null;
    let step;
    if (prompt == null) step = "(no prompt)";
    else if (prev != null && prompt.startsWith(prev) && prompt.length > prev.length) {
      step = prompt.slice(prev.length); if (step.startsWith(" / ")) step = step.slice(3);
    } else step = lastStep(prompt);
    if (h.hash === loaded) seen = true;
    out.unshift({ hash: h.hash, time: (h.time ?? "").slice(5, 16).replace("T", " "), step, loaded: h.hash === loaded });
    if (prompt != null) prev = prompt;
  }
  if (!seen && loaded) out.unshift({ hash: loaded, time: "", step: "edited in place (refining the version below)", loaded: true });
  let parent = null, tags = [];
  try { const info = JSON.parse(fs.readFileSync(path.join(dir, "info.json"), "utf8")); parent = info.parent ?? null; tags = info.tags ?? []; } catch {}
  return { type: "trail", kind, name, versions: lines.length, lines: out, parent, tags,
    synth: kind === "pattern" ? entry?.synth : undefined, itemKind: kind === "synth" ? entry?.kind : undefined };
}

// --- the focus: what the page shows and what "this" means in the terminal ---
let focus = null, lastFocusJson = "";
function setFocus(kind, name) {
  if (!name || (kind !== "synth" && kind !== "pattern")) return;
  if (focus && focus.kind === kind && focus.name === name) return;
  focus = { kind, name };
  broadcast({ type: "focus", ...focus });
  writeFocus();
}
function writeFocus() {
  const playing = lastStatus ? [
    ...lastStatus.patterns.filter((p) => p.playing).map((p) => ({ kind: "pattern", name: p.name, synth: p.synth })),
    ...lastStatus.synths.filter((y) => y.playing).map((y) => ({ kind: "synth", name: y.name })),
  ] : [];
  const entry = focus && lastStatus && (focus.kind === "synth" ? lastStatus.synths : lastStatus.patterns).find((e) => e.name === focus.name);
  const json = JSON.stringify({ pid: process.pid, selected: focus && { ...focus, synth: focus.kind === "pattern" ? entry?.synth : undefined }, playing });
  if (json === lastFocusJson) return;
  lastFocusJson = json;
  try { fs.mkdirSync(runDir, { recursive: true }); fs.writeFileSync(focusFile, json + "\n"); } catch {}
}
const removeFocus = () => { try { fs.unlinkSync(focusFile); } catch {} };
process.on("exit", removeFocus);
for (const sig of ["SIGINT", "SIGTERM", "SIGHUP"]) process.on(sig, () => process.exit(0));

// --- commands the page may send ---
const commands = {
  "select": (a) => setFocus(a.kind, a.name),
  "pattern/play": (a) => toEngine("/ps/pattern/play", [a.name]),
  "pattern/stop": (a) => toEngine("/ps/pattern/stop", [a.name]),
  "synth/play": (a) => toEngine("/ps/synth/play", [a.name]),
  "synth/release": (a) => toEngine("/ps/synth/release", [a.name]),
  "panic": () => toEngine("/ps/panic"),
  // history player: steps of the selected item, load a step by its index, back to the latest
  "history/steps": (a) => toEngine("/ps/history/steps", [a.kind, a.name]),
  "history/load": (a) => toEngine("/ps/history/load", [a.kind, a.name, Math.trunc(Number(a.index))]),
  "history/end": () => toEngine("/ps/history/end"),
  // one thing at a time: stop every other pattern and synth that's playing, then play this one
  "solo": (a) => {
    if (!lastStatus) return;
    for (const p of lastStatus.patterns) if (p.playing && !(a.kind === "pattern" && p.name === a.name)) toEngine("/ps/pattern/stop", [p.name]);
    for (const y of lastStatus.synths) if (y.playing && !(a.kind === "synth" && y.name === a.name)) toEngine("/ps/synth/release", [y.name]);
    toEngine(a.kind === "synth" ? "/ps/synth/play" : "/ps/pattern/play", [a.name]);
  },
};

// --- engine status: polled; an answer also means the engine is up, so (re)subscribe ---
let lastStatusAt = 0, engineUp = false, lastStatus = null;
setInterval(() => {
  toEngine("/ps/status");
  const up = Date.now() - lastStatusAt < 2000;
  if (up !== engineUp) { engineUp = up; broadcast({ type: "engine", up }); if (up) toEngine("/ps/subscribe", [oscPort]); }
}, 500);
setInterval(() => { if (engineUp) toEngine("/ps/subscribe", [oscPort]); }, 5000);   // after an engine restart

osc.on("message", (buf) => {
  let m;
  try { m = decode(buf); } catch { return; }
  if (m.addr === "/ps/result") {
    let r = null;
    try { r = JSON.parse(m.args[1]); } catch {}
    if (m.args[0] === "status" && r) { lastStatusAt = Date.now(); lastStatus = r; broadcast({ type: "status", status: r }); writeFocus(); }
    else if (String(m.args[0]).startsWith("history/") && r) broadcast({ type: "history", path: m.args[0], res: r });
    else if (r && r.ok === false) broadcast({ type: "log", text: `${m.args[0]} failed: ${(r.errors ?? []).join("; ")}` });
  } else if (m.addr.startsWith("/ps/event/")) {
    const ev = m.addr.slice(10), a = m.args;
    // the terminal's work moves the focus: a new version, or something that starts playing (a
    // playing pattern is re-announced when its synth or source changes: that doesn't move it)
    if (ev === "defined") setFocus(a[0], a[1]);
    else if (ev === "pattern" && a[1] === 1 && !lastStatus?.patterns.find((p) => p.name === a[0])?.playing) setFocus("pattern", a[0]);
    else if (ev === "synth" && a[1] === 1) setFocus("synth", a[0]);
    broadcast({ type: "event", name: ev, args: a });
  } else if (m.addr === "/cc/event") {
    broadcast({ type: "cc", event: m.args[0] ?? "", kind: m.args[1] ?? "", detail: m.args[2] ?? "" });
  }
});
osc.bind(oscPort, "127.0.0.1");

// --- HTTP: static files and the WebSocket upgrade ---
const types = { ".html": "text/html; charset=utf-8", ".js": "text/javascript", ".css": "text/css" };
const server = http.createServer((req, res) => {
  const p = path.normalize(decodeURIComponent(new URL(req.url, "http://x").pathname)).replace(/^(\.\.[/\\])+/, "");
  const file = path.join(publicDir, p === "/" ? "index.html" : p);
  if (!file.startsWith(publicDir)) { res.writeHead(403).end(); return; }
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404).end("not found"); return; }
    res.writeHead(200, { "Content-Type": types[path.extname(file)] ?? "application/octet-stream", "Cache-Control": "no-store" }).end(data);
  });
});
server.on("upgrade", (req, sock) => {
  if (req.url !== "/ws" || !req.headers["sec-websocket-key"]) { sock.destroy(); return; }
  const accept = crypto.createHash("sha1").update(req.headers["sec-websocket-key"] + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").digest("base64");
  sock.write(`HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: ${accept}\r\n\r\n`);
  clients.add(sock);
  sock.on("close", () => clients.delete(sock));
  sock.on("error", () => clients.delete(sock));
  wsSend(sock, JSON.stringify({ type: "engine", up: engineUp }));
  if (focus) wsSend(sock, JSON.stringify({ type: "focus", ...focus }));
  wsFrames(sock, (text) => {
    let msg;
    try { msg = JSON.parse(text); } catch { return; }
    if (msg.cmd === "trail") { const t = trail(msg.kind, msg.name); if (t) wsSend(sock, JSON.stringify(t)); return; }
    const f = commands[msg.cmd];
    if (f) f(msg); else wsSend(sock, JSON.stringify({ type: "log", text: `unknown command ${msg.cmd}` }));
  });
});
server.listen(httpPort, "127.0.0.1", () => {
  console.log(`PromptSynth web UI: http://127.0.0.1:${httpPort}/  (engine OSC ${enginePort}, bridge OSC ${oscPort})`);
});
