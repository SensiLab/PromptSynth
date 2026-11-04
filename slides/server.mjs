#!/usr/bin/env node
// PromptSynth slides: the code-as-instrument story as a deck, with the engine built in. Serves
// slides/public/ on http://127.0.0.1:8092 and relays a few engine calls over plain HTTP:
//
//   GET  /api/status              the engine's last /ps/status (polled every 0.5 s), or {up:false}
//   GET  /api/source?kind=&name=  a synth's synthdef.scd or a pattern's pattern.scd, as text
//   GET  /api/steps?kind=&name=   the history of making (/ps/history/steps), waits for the reply
//   POST /api/cmd {cmd, ...}      pattern/play, pattern/stop, synth/play, synth/release, panic,
//                                 history/load {kind, name, index}, history/end
//
// Plain Node, no dependencies, separate from web/ (own ports, so both can run). Local only.
// Env: PS_PORT engine port (57120), PS_SLIDES_OSC_PORT this server's OSC port (57132),
// PS_SLIDES_PORT (8092).
import dgram from "node:dgram";
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const enginePort = Number(process.env.PS_PORT ?? 57120);
const oscPort = Number(process.env.PS_SLIDES_OSC_PORT ?? 57132);
const httpPort = Number(process.env.PS_SLIDES_PORT ?? 8092);
const publicDir = path.join(path.dirname(fileURLToPath(import.meta.url)), "public");

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

// --- engine status, and replies waited on by path ---
let lastStatus = null, lastStatusAt = 0;
const waiting = [];   // {path, resolve}
setInterval(() => toEngine("/ps/status"), 500);
osc.on("message", (buf) => {
  let m;
  try { m = decode(buf); } catch { return; }
  if (m.addr !== "/ps/result") return;
  let r = null;
  try { r = JSON.parse(m.args[1]); } catch { return; }
  const p = String(m.args[0]).replace(/^\/?ps\//, "");
  if (p === "status") { lastStatus = r; lastStatusAt = Date.now(); return; }
  const i = waiting.findIndex((w) => w.path === p);
  if (i >= 0) waiting.splice(i, 1)[0].resolve(r);
});
osc.bind(oscPort, "127.0.0.1");
function ask(p, args, ms = 3000) {
  return new Promise((resolve) => {
    const w = { path: p, resolve };
    waiting.push(w);
    toEngine("/ps/" + p, args);
    setTimeout(() => { const i = waiting.indexOf(w); if (i >= 0) { waiting.splice(i, 1); resolve({ ok: false, errors: ["no reply from the engine"] }); } }, ms);
  });
}
const up = () => Date.now() - lastStatusAt < 2000;

const validName = (n) => /^[A-Za-z][A-Za-z0-9_]*$/.test(n ?? "");
const validKind = (k) => k === "synth" || k === "pattern";
function sourceFile(kind, name) {
  const lib = lastStatus?.libraryDir ?? path.join(publicDir, "..", "..", "library");
  return kind === "synth" ? path.join(lib, "synths", name, "synthdef.scd") : path.join(lib, "patterns", name, "pattern.scd");
}

const commands = {
  "pattern/play": (a) => toEngine("/ps/pattern/play", [a.name]),
  "pattern/stop": (a) => toEngine("/ps/pattern/stop", [a.name]),
  "synth/play": (a) => toEngine("/ps/synth/play", [a.name]),
  "synth/release": (a) => toEngine("/ps/synth/release", [a.name]),
  "panic": () => toEngine("/ps/panic"),
  "history/load": (a) => toEngine("/ps/history/load", [a.kind, a.name, Math.trunc(Number(a.index))]),
  "history/end": () => toEngine("/ps/history/end"),
};

const json = (res, code, obj) => res.writeHead(code, { "Content-Type": "application/json", "Cache-Control": "no-store" }).end(JSON.stringify(obj));
const types = { ".html": "text/html; charset=utf-8", ".js": "text/javascript", ".css": "text/css" };

http.createServer(async (req, res) => {
  const url = new URL(req.url, "http://x");
  const q = Object.fromEntries(url.searchParams);
  if (url.pathname === "/api/status") return json(res, 200, up() ? { up: true, ...lastStatus } : { up: false });
  if (url.pathname === "/api/source") {
    if (!validKind(q.kind) || !validName(q.name)) return json(res, 400, { ok: false });
    return fs.readFile(sourceFile(q.kind, q.name), "utf8", (err, text) => err ? json(res, 404, { ok: false }) : json(res, 200, { ok: true, text }));
  }
  if (url.pathname === "/api/steps") {
    if (!validKind(q.kind) || !validName(q.name)) return json(res, 400, { ok: false });
    return json(res, 200, await ask("history/steps", [q.kind, q.name]));
  }
  if (url.pathname === "/api/cmd" && req.method === "POST") {
    let body = "";
    req.on("data", (c) => { body += c; });
    req.on("end", () => {
      let a;
      try { a = JSON.parse(body); } catch { return json(res, 400, { ok: false }); }
      const f = commands[a.cmd];
      if (!f || (a.name !== undefined && !validName(a.name)) || (a.kind !== undefined && !validKind(a.kind))) return json(res, 400, { ok: false });
      f(a);
      json(res, 200, { ok: true });
    });
    return;
  }
  const p = path.normalize(decodeURIComponent(url.pathname)).replace(/^(\.\.[/\\])+/, "");
  const file = path.join(publicDir, p === "/" ? "index.html" : p);
  if (!file.startsWith(publicDir)) return res.writeHead(403).end();
  fs.readFile(file, (err, data) => {
    if (err) return res.writeHead(404).end("not found");
    res.writeHead(200, { "Content-Type": types[path.extname(file)] ?? "application/octet-stream", "Cache-Control": "no-store" }).end(data);
  });
}).listen(httpPort, "127.0.0.1", () => {
  console.log(`PromptSynth slides: http://127.0.0.1:${httpPort}/  (engine OSC ${enginePort}, slides OSC ${oscPort})`);
});
