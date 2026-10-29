// The library on disk:
//   synths/<name>/synthdef.scd        current source
//   synths/<name>/meta.json           kind, params + specs, hash, last validation (engine-owned)
//   synths/<name>/info.json           caller's info for the current version (prompt, parent, tags...)
//   synths/<name>/history.jsonl       one line per new version: {"time", "hash", "info"}
//   synths/<name>/versions/<hash>.scd every version, stored by content hash
//   synths/<name>/recordings/
//   patterns/<name>/pattern.scd, meta.json (bound synth, keys), info.json, history.jsonl, versions/
//   patterns/<name>/pairings.jsonl    play/stop log: which synth version played which pattern version
//   _state.json                       orchestra settings: param values, mappings, master, tempo
//   _recordings/, _failed/
(
synthDir: { |self, name| self.libraryDir +/+ "synths" +/+ name.asString },
patternDir: { |self, name| self.libraryDir +/+ "patterns" +/+ name.asString },

// SHA-1 of the file, first 12 hex digits: the same as `shasum -a 1`. Computed here rather than by
// running shasum, because starting a shell from sclang blocks the interpreter (and every playing
// pattern with it) for most of a second. sclang Integers are 32-bit and wrap, as SHA-1 needs.
fileHash: { |self, path|
	var bytes, n, w = Array.newClear(80), hex = "0123456789abcdef";
	var h = [1732584193, -271733879, -1732584194, 271733878, -1009589776];
	var rotl = { |x, s| (x << s) | (x >> (32 - s)).bitAnd((1 << s) - 1) };
	File.use(path, "rb", { |f| bytes = Int8Array.newClear(f.length); f.read(bytes) });
	n = bytes.size;
	// padding: 0x80, zeros up to 56 mod 64, then the length in bits as 64-bit big-endian
	bytes = bytes.asArray.collect(_.bitAnd(255)) ++ [128] ++ (0 ! ((55 - n) % 64))
		++ [0, 0, 0, 0] ++ [24, 16, 8, 0].collect { |s| ((n * 8) >> s).bitAnd(255) };
	(bytes.size div: 64).do { |block|
		var a, b, c, d, e, f, k, t, base = block * 64;
		16.do { |i|
			var j = base + (i * 4);
			w[i] = (bytes[j] << 24) | (bytes[j + 1] << 16) | (bytes[j + 2] << 8) | bytes[j + 3]
		};
		(16..79).do { |i| w[i] = rotl.(w[i - 3].bitXor(w[i - 8]).bitXor(w[i - 14]).bitXor(w[i - 16]), 1) };
		#a, b, c, d, e = h;
		80.do { |i|
			case
			{ i < 20 } { f = (b & c) | (b.bitNot & d); k = 1518500249 }
			{ i < 40 } { f = b.bitXor(c).bitXor(d); k = 1859775393 }
			{ i < 60 } { f = (b & c) | (b & d) | (c & d); k = -1894007588 }
			{ f = b.bitXor(c).bitXor(d); k = -899497514 };
			t = rotl.(a, 5) + f + e + k + w[i];
			e = d; d = c; c = rotl.(b, 30); b = a; a = t;
		};
		h = h + [a, b, c, d, e];
	};
	h.collect { |x| 8.collect { |i| hex[(x >> (28 - (i * 4))).bitAnd(15)] } }.flat.join.keep(12)
},

appendLine: { |self, path, str|
	File.mkdir(path.dirname);
	File.use(path, "a", { |f| f.write(str ++ "\n") });
},

lastHash: { |self, dir|
	var lines = (self.readFile(dir +/+ "history.jsonl") ? "").split($\n).reject(_.isEmpty);
	if (lines.notEmpty) { lines.last.parseJSON["hash"] }
},

// writes the current source, keeps it under versions/<hash>.scd and logs it if it's new; returns the hash
saveSource: { |self, dir, file, src, infoJson|
	var dst = dir +/+ file, vdir = dir +/+ "versions", hash;
	self.writeFile(dst, src);
	hash = self.fileHash(dst);
	File.mkdir(vdir);
	if (File.exists(vdir +/+ hash ++ ".scd").not) { File.copy(dst, vdir +/+ hash ++ ".scd") };
	if (self.lastHash(dir) != hash) {
		// JSON can only have raw newlines outside strings, so flattening them keeps it valid
		self.appendLine(dir +/+ "history.jsonl", "{\"time\":%,\"hash\":%,\"info\":%}".format(
			self.jsonQuote(self.isoNow), self.jsonQuote(hash),
			if (infoJson.notNil and: { infoJson.size > 0 }) { infoJson.tr($\n, $ ) } { "null" }));
	};
	if (infoJson.notNil and: { infoJson.size > 0 }) { self.writeFile(dir +/+ "info.json", infoJson) };
	hash
},

saveSynth: { |self, name, src, infoJson, res|
	var dir = self.synthDir(name);
	var hash = self.saveSource(dir, "synthdef.scd", src, infoJson);
	self.writeFile(dir +/+ "meta.json", self.jsonEncode((name: name, hash: hash, kind: res[\kind],
		source: res[\source], channels: res[\channels], params: res[\params], updated: self.isoNow,
		validation: (peakDb: res[\peakDb], rmsDb: res[\rmsDb], warnings: res[\warnings]))));
	hash
},

writePatternMeta: { |self, p|
	self.writeFile(self.patternDir(p[\name]) +/+ "meta.json", self.jsonEncode((name: p[\name],
		hash: p[\hash], synth: p[\synth], keys: p[\keys].asArray.sort, updated: self.isoNow)));
},

archiveFailure: { |self, name, src, res|
	var base = self.libraryDir +/+ "_failed" +/+ self.timestamp ++ "_" ++ name.asString.select(_.isAlphaNum);
	self.writeFile(base ++ ".scd", src);
	self.writeFile(base ++ ".json", self.jsonEncode(res));
},

// (re)loads every synth and pattern without smoke tests; call from a Routine
loadLibrary: { |self|
	var loaded = List[], failed = List[], folders = { |dir|
		File.mkdir(dir);
		PathName(dir).folders.reject { |pn| pn.folderName.beginsWith("_") }
	};
	if (File.exists(self.libraryDir +/+ "synths").not and: {
		PathName(self.libraryDir).folders.any { |pn| File.exists(pn.fullPath +/+ "synthdef.scd") } }) {
		self.log("WARNING: old library layout (library/<name>/synthdef.scd); synths now live in library/synths/<name>/");
	};
	folders.(self.libraryDir +/+ "synths").do { |pn|
		var name = pn.folderName, src = pn.fullPath +/+ "synthdef.scd", res;
		if (File.exists(src)) {
			res = self.runDefine(name.asSymbol, src, nil, (smoke: false, save: false));
			if (res[\ok]) { loaded.add(name) } { failed.add(name) };
		}
	};
	folders.(self.libraryDir +/+ "patterns").do { |pn|
		var name = pn.folderName, src = pn.fullPath +/+ "pattern.scd", meta, res;
		if (File.exists(src)) {
			meta = (self.readFile(pn.fullPath +/+ "meta.json") ? "{}").parseJSON;
			res = self.definePattern(name.asSymbol, src, meta["synth"] !? (_.asSymbol), nil, false);
			if (res[\ok]) { loaded.add("pattern " ++ name) } { failed.add("pattern " ++ name) };
		}
	};
	self.log("library: % loaded%".format(loaded.size,
		if (failed.notEmpty) { ", failed: " ++ failed.join(", ") } { "" }));
	(ok: failed.isEmpty, loaded: loaded.asArray, failed: failed.asArray)
},

// --- orchestra settings, saved shortly after each change and restored at boot ---

stateFile: { |self| self.libraryDir +/+ "_state.json" },

saveStateSoon: { |self|
	var token = UniqueID.next;
	self.stateToken = token;
	SystemClock.sched(1, { if (self.stateToken == token) { self.saveState }; nil });
},

saveState: { |self|
	var synths = ();
	self.synths.keysValuesDo { |name, e|
		var mappings = ();
		e[\mappings].keysValuesDo { |param, m|
			mappings[param] = (channel: m[\channel], min: m[\min], max: m[\max], warp: m[\warp])
		};
		synths[name] = (values: e[\paramValues], mappings: mappings);
	};
	self.writeFile(self.stateFile, self.jsonEncode((master: self.config[\masterAmp],
		tempo: TempoClock.default.tempo * 60, synths: synths, saved: self.isoNow)));
},

restoreState: { |self|
	var st = self.readFile(self.stateFile) !? { |s| try { s.parseJSON } { nil } };
	var num = { |v| if (v.isNumber) { v } { v.asString.asFloat } };
	if (st.notNil) {
		st["master"] !? { |v| self.setMasterAmp(num.(v)) };
		st["tempo"] !? { |v| self.setTempo(num.(v)) };
		(st["synths"] ?? { () }).keysValuesDo { |name, s|
			var e = self.synths[name.asSymbol];
			if (e.notNil) {
				(s["values"] ?? { () }).keysValuesDo { |k, v|
					var p = e[\params].detect { |p| p[\name] == k.asSymbol };
					if (p.notNil and: { p[\rate] != \array }) { try { self.setParam(name, k, num.(v)) } };
				};
				(s["mappings"] ?? { () }).keysValuesDo { |k, m|
					var warp = m["warp"].asString;
					warp = if (warp.asFloat != 0 or: { warp == "0" }) { warp.asFloat } { warp.asSymbol };
					try { self.mapParam(name, k, m["channel"], num.(m["min"]), num.(m["max"]), warp) }
						{ |err| self.log("couldn't restore mapping %.%: %".format(name, k, self.errorText(err))) };
				};
			}
		};
		self.log("restored settings from %".format(self.stateFile.basename));
	}
}
)
