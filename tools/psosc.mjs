#!/usr/bin/env node
// Send one OSC message to the PromptSynth engine and print the /ps/result reply, if any.
//
//   node tools/psosc.mjs /ps/status
//   node tools/psosc.mjs /ps/synth/define pad /abs/path/pad.scd
//   node tools/psosc.mjs /ps/param/set pad cutoff 800
//
// Args that look like numbers are sent as floats (append "i" for int32, e.g. 4i),
// everything else as strings. PS_PORT overrides the engine port (default 57120).
// Waits up to PS_TIMEOUT ms (default 15000) for a reply; commands that only reply on
// error give up after 500 ms.
import dgram from "node:dgram";

const port = Number(process.env.PS_PORT ?? 57120);
const [address, ...rawArgs] = process.argv.slice(2);
if (!address?.startsWith("/")) {
  console.error("usage: psosc.mjs /osc/address [args...]");
  process.exit(2);
}

const alwaysReply = new Set([
  "/ps/ping", "/ps/status", "/ps/subscribe", "/ps/unsubscribe", "/ps/synth/define",
  "/ps/param/get", "/ps/pattern/define", "/ps/pattern/default", "/ps/pattern/play", "/ps/pattern/get",
  "/ps/channel/list", "/ps/map", "/ps/unmap", "/ps/rec/start", "/ps/rec/stop", "/ps/library/reload",
]);

const pad4 = (buf) => Buffer.concat([buf, Buffer.alloc(4 - (buf.length % 4))]);
const oscString = (s) => pad4(Buffer.from(s, "utf8"));

function encode(addr, args) {
  let tags = ",";
  const parts = [];
  for (const a of args) {
    if (/^-?\d+i$/.test(a)) {
      tags += "i";
      const b = Buffer.alloc(4); b.writeInt32BE(parseInt(a, 10)); parts.push(b);
    } else if (a !== "" && !isNaN(Number(a))) {
      tags += "f";
      const b = Buffer.alloc(4); b.writeFloatBE(Number(a)); parts.push(b);
    } else {
      tags += "s";
      parts.push(oscString(a));
    }
  }
  return Buffer.concat([oscString(addr), oscString(tags), ...parts]);
}

function decode(buf) {
  let off = 0;
  const str = () => {
    const end = buf.indexOf(0, off);
    const s = buf.toString("utf8", off, end);
    off = (end + 4) & ~3;
    return s;
  };
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

const sock = dgram.createSocket("udp4");
const timeout = alwaysReply.has(address) ? Number(process.env.PS_TIMEOUT ?? 15000) : 500;
const timer = setTimeout(() => {
  if (alwaysReply.has(address)) { console.error(`no reply from engine on port ${port}`); process.exitCode = 1; }
  sock.close();
}, timeout);

sock.on("message", (buf) => {
  const { addr, args } = decode(buf);
  if (addr !== "/ps/result") return;
  clearTimeout(timer);
  let out = args[1];
  try { out = JSON.stringify(JSON.parse(args[1]), null, 2); } catch {}
  console.log(out);
  try { if (JSON.parse(args[1]).ok === false) process.exitCode = 1; } catch {}
  sock.close();
});

sock.send(encode(address, rawArgs), port, "127.0.0.1");
