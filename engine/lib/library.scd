// The synth library on disk:
//   library/<name>/synthdef.scd   source (engine-owned)
//   library/<name>/meta.json      kind, params, specs, last validation (engine-owned)
//   library/<name>/info.json      prompt, parent, tags... written verbatim from the caller
//   library/<name>/pattern.scd    optional pattern for this synth
//   library/<name>/versions/      previous sources
//   library/<name>/recordings/    audio recorded while this synth was the focus
//   library/_failed/              sources and results of definitions that failed
(
synthDir: { |self, name| self.libraryDir +/+ name.asString },

// writes `src` to `file` inside the synth dir, keeping the previous version if it changed
saveVersioned: { |self, name, file, src|
	var dir = self.synthDir(name), dst = dir +/+ file, old = self.readFile(dst);
	if (old.notNil and: { old != src }) {
		File.mkdir(dir +/+ "versions");
		File.copy(dst, dir +/+ "versions" +/+ file.splitext[0] ++ "_" ++ self.timestamp ++ ".scd");
	};
	if (old != src) { self.writeFile(dst, src) };
},

saveSynth: { |self, name, src, infoJson, res|
	var dir = self.synthDir(name);
	var meta = (name: name, kind: res[\kind], source: res[\source], channels: res[\channels],
		params: res[\params], updated: self.isoNow,
		validation: (peakDb: res[\peakDb], rmsDb: res[\rmsDb], warnings: res[\warnings]));
	self.saveVersioned(name, "synthdef.scd", src);
	self.writeFile(dir +/+ "meta.json", self.jsonEncode(meta));
	if (infoJson.notNil and: { infoJson.size > 0 }) { self.writeFile(dir +/+ "info.json", infoJson) };
},

archiveFailure: { |self, name, src, res|
	var base = self.libraryDir +/+ "_failed" +/+ self.timestamp ++ "_" ++ name.asString.select(_.isAlphaNum);
	self.writeFile(base ++ ".scd", src);
	self.writeFile(base ++ ".json", self.jsonEncode(res));
},

// (re)loads every synth in the library without smoke tests; call from a Routine
loadLibrary: { |self|
	var loaded = List[], failed = List[];
	File.mkdir(self.libraryDir);
	PathName(self.libraryDir).folders.do { |pn|
		var name = pn.folderName, src = pn.fullPath +/+ "synthdef.scd", pat = pn.fullPath +/+ "pattern.scd", res;
		if (name.beginsWith("_").not and: { File.exists(src) }) {
			res = self.runDefine(name.asSymbol, src, nil, (smoke: false, save: false));
			if (res[\ok]) {
				loaded.add(name);
				if (File.exists(pat)) { self.definePattern(name.asSymbol, pat, false) };
			} { failed.add(name) };
		}
	};
	self.log("library: % loaded%".format(loaded.size,
		if (failed.notEmpty) { ", failed: " ++ failed.join(", ") } { "" }));
	(ok: failed.isEmpty, loaded: loaded.asArray, failed: failed.asArray)
}
)
