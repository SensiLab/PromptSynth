// History player: steps through the history of making a pairing, a pattern and its synth (their
// versions in history.jsonl, in time order). Old versions load the way the watcher reloads a
// file: in memory only, no new version, no history line.
//
// While the player is active, nothing is written to pairings.jsonl (replaying mustn't add to the
// history it reads) and settings aren't saved: an old version without a param drops that
// param's mapping, and _state.json mustn't keep the loss. historyEnd puts the latest versions
// back with the values and mappings they had when the player started.
(
historyActive: false,

versionFile: { |self, kind, name, hash|
	var dir = if (kind == \synth) { self.synthDir(name) } { self.patternDir(name) };
	hash !? { dir +/+ "versions" +/+ hash ++ ".scd" }
},

// the history of making a pairing: a pattern's versions and its synth's versions (history.jsonl,
// each with its prompt) merged in time order, oldest first. A step is the pairing after one of
// them was made: that pattern version on that synth version; `change` says which was made and
// `step` is the new part of its prompt. It starts once both exist. For a synth: its own versions
// (no pattern). A version loads from versions/ or, if it's the current one, from the library
// file. A step is `playable` when its versions load, `current` when they're the current files.
// Reads files: call on selection, not per frame.
historySteps: { |self, kind, name|
	var events = List[], steps = List[], currents = IdentityDictionary(), seq = 0;
	var pattern, synth, pHash, sHash;
	var source = { |kind, name, hash|
		var lib = if (kind == \synth) { self.synthDir(name) +/+ "synthdef.scd" } { self.patternDir(name) +/+ "pattern.scd" };
		var file = self.versionFile(kind, name, hash), key = (kind ++ ":" ++ name).asSymbol;
		currents[key] = currents[key] ?? { if (File.exists(lib)) { self.fileHash(lib) } };
		case
			{ file.notNil and: { File.exists(file) } } { [file, hash == currents[key]] }
			{ hash.notNil and: { hash == currents[key] } } { [lib, true] }
			{ [nil, false] }
	};
	// one item's versions, each with the part of its prompt that's new since the one before
	var read = { |kind, name|
		var dir = if (kind == \synth) { self.synthDir(name) } { self.patternDir(name) }, prev;
		(self.readFile(dir +/+ "history.jsonl") ? "").split($\n).do { |l|
			var h = try { l.parseJSON } { nil }, pr, step;
			if (h.isKindOf(Dictionary) and: { h["hash"].notNil }) {
				pr = h["info"] !? { |i| if (i.isKindOf(Dictionary)) { i["prompt"] } };
				step = case
					{ pr.isNil } { "(no prompt)" }
					{ prev.notNil and: { pr.beginsWith(prev) } and: { pr.size > prev.size } } {
						step = pr.drop(prev.size);
						if (step.beginsWith(" / ")) { step.drop(3) } { step } }
					{ pr.findBackwards(" / ") !? { |i| pr.drop(i + 3) } ? pr };
				pr !? { prev = pr };
				seq = seq + 1;
				events.add((time: h["time"].asString, seq: seq, kind: kind, hash: h["hash"].asString, step: step));
			}
		}
	};
	name = name.asSymbol;
	if (kind == \pattern) {
		pattern = name;
		synth = self.patterns[name] !? { |p| p[\synth] };
		read.(\pattern, pattern);
		synth !? { read.(\synth, synth) };
		// a synth with no stored versions plays as it is now
		if (synth.notNil and: { events.every { |e| e[\kind] == \pattern } }) { sHash = self.synths[synth] !? { |e| e[\hash] } };
	} {
		synth = name;
		read.(\synth, synth);
	};
	events.sort { |a, b| if (a[\time] == b[\time]) { a[\seq] <= b[\seq] } { a[\time] < b[\time] } }.do { |ev|
		if (ev[\kind] == \pattern) { pHash = ev[\hash] } { sHash = ev[\hash] };
		if ((pattern.isNil or: { pHash.notNil }) and: { sHash.notNil }) {
			var s = (time: ev[\time], change: ev[\kind], step: ev[\step], pattern: pattern, patternHash: pHash,
				synth: synth, synthHash: sHash), p, y;
			p = if (pattern.notNil) { source.(\pattern, pattern, pHash) } { [nil, true] };
			y = source.(\synth, synth, sHash);
			s[\patternFile] = p[0]; s[\synthFile] = y[0];
			s[\patternStored] = p[0].notNil; s[\synthStored] = y[0].notNil;
			s[\playable] = (pattern.isNil or: { s[\patternStored] }) and: { s[\synthStored] };
			s[\current] = p[1] and: { y[1] };
			steps.add(s);
		}
	};
	steps.asArray
},

historyBegin: { |self|
	if (self.historyActive.not) {
		self.historySnapshot = IdentityDictionary();
		self.synths.keysValuesDo { |name, e|
			var maps = IdentityDictionary();
			e[\mappings].keysValuesDo { |k, m| maps[k] = (channel: m[\channel], min: m[\min], max: m[\max], warp: m[\warp]) };
			self.historySnapshot[name] = (values: e[\paramValues].copy, mappings: maps);
		};
		self.historyTouched = Dictionary();
		self.historyActive = true;
		self.log("history: player started (settings aren't saved until it ends)");
	}
},

// loads a step's synth and pattern versions (whichever are stored) and plays the pattern if it
// isn't playing; a playing pattern swaps on its bar line. Call from a Routine.
historyLoad: { |self, step|
	var res = (synth: \missing, pattern: \missing), lib;
	self.historyBegin;
	if (step[\synthStored]) {
		res[\synth] = if (self.runDefine(step[\synth], step[\synthFile], nil, (save: false, smoke: false))[\ok]) { \loaded } { \failed };
		lib = self.synthDir(step[\synth]) +/+ "synthdef.scd";
		if (File.exists(lib)) { self[\watchMtimes][lib] = File.mtime(lib) };   // the watcher must not put the latest back
		self.historyTouched["synth:" ++ step[\synth]] = [\synth, step[\synth]];
	};
	if (step[\patternStored]) {
		res[\pattern] = if (self.definePattern(step[\pattern], step[\patternFile], step[\synth], nil, false)[\ok]) { \loaded } { \failed };
		lib = self.patternDir(step[\pattern]) +/+ "pattern.scd";
		if (File.exists(lib)) { self[\watchMtimes][lib] = File.mtime(lib) };
		self.historyTouched["pattern:" ++ step[\pattern]] = [\pattern, step[\pattern]];
	};
	if (self.patterns[step[\pattern]].notNil and: { self.patternPlaying(step[\pattern]).not }) {
		try { self.playPattern(step[\pattern]) } { |err| res[\error] = self.errorText(err) }
	};
	self.log("history: % % (synth %) on % % (synth %)".format(step[\pattern], step[\patternHash], res[\pattern],
		step[\synth], step[\synthHash], res[\synth]));
	res
},

// back to the latest versions, with the values and mappings from when the player started.
// Call from a Routine.
historyEnd: { |self|
	if (self.historyActive) {
		self.historyTouched.do { |t|
			var kind = t[0], name = t[1];
			if (kind == \synth) {
				self.runDefine(name, self.synthDir(name) +/+ "synthdef.scd", nil, (save: false, smoke: false))
			} {
				self.definePattern(name, self.patternDir(name) +/+ "pattern.scd", nil, nil, false)
			}
		};
		self.historySnapshot.keysValuesDo { |name, snap|
			var e = self.synths[name];
			if (e.notNil) {
				snap[\values].keysValuesDo { |k, v| if (e[\params].any { |p| p[\name] == k }) { try { self.setParam(name, k, v) } } };
				snap[\mappings].keysValuesDo { |k, m|
					if (e[\mappings][k].isNil and: { e[\params].any { |p| p[\name] == k } }) {
						try { self.mapParam(name, k, m[\channel], m[\min], m[\max], m[\warp]) }
							{ |err| self.log("history: couldn't restore mapping %.%: %".format(name, k, self.errorText(err))) }
					}
				};
			}
		};
		self.historyActive = false;
		self.historySnapshot = nil;
		self.historyTouched = nil;
		self.saveStateSoon;
		self.log("history: back to the latest versions");
	}
}
)
