// Named patterns. A pattern plays one synth at a time (its binding) and the engine chains it with
// that synth's param buses, so /ps/param/set and mappings reach every note. Every play/stop is
// logged to patterns/<name>/pairings.jsonl with both version hashes.
(
// keys the default Event uses itself: never bus-mapped, and fine for a pattern to set
eventKeys: #[freq, midinote, note, degree, octave, root, scale, dur, legato, sustain, stretch,
	detune, harmonic, ctranspose, mtranspose, gtranspose, lag, timingOffset, tempo, db,
	instrument, group, out, type, addAction, hasGate, server, latency, variant],

patternDefaults: { |self|
	(degree: [0, 2, 4, 7], dur: [0.25], octave: [5], legato: [0.8], scale: [\major], root: [0])
},

patternEntry: { |self, name|
	self.patterns[name.asSymbol] ?? { Error("unknown pattern '%'".format(name)).throw }
},

pdefKey: { |self, name| ("ps_pat_" ++ name).asSymbol },

patternPlaying: { |self, name| Pdef.all[self.pdefKey(name)] !? { |p| p.isPlaying } ? false },

// keys a pattern sets that don't reach its synth
keyCheck: { |self, p, e|
	var params = e[\params].collect(_[\name]);
	var warnings = p[\keys].asArray.sort.reject { |k| params.includes(k) or: { self.eventKeys.includes(k) } }.collect { |k|
		"pattern '%' sets `%`, but % has no such param".format(p[\name], k, e[\name])
	};
	#[out, group].do { |k|
		if (p[\keys].includes(k)) { warnings = warnings.add("pattern '%' sets `%`, which overrides the engine's routing".format(p[\name], k)) }
	};
	warnings
},

updatePdef: { |self, p|
	var e = self.synthEntry(p[\synth]), pairs, inner;
	var base = [\instrument, e[\name], \out, Pfunc { self.masterBus.index }, \group, Pfunc { self.sourceGroup }];
	e[\params].do { |prm|
		var k = prm[\name];
		if (self.eventKeys.includes(k).not) {
			case
			{ prm[\rate] == \control } { base = base ++ [k, e[\buses][k].asMap] }
			{ #[scalar, trigger].includes(prm[\rate]) } { base = base ++ [k, Pfunc { e[\paramValues][k] }] }
		}
	};
	pairs = p[\overrides].keys.asArray.sort.collect { |k| [k, p[\overrides][k]] }.flatten;
	inner = case
		{ p[\userPattern].isNil } { Pbind(*pairs) }
		{ pairs.isEmpty } { p[\userPattern] }
		{ Pbindf(p[\userPattern], *pairs) };
	Pdef(self.pdefKey(p[\name]), Pchain(inner, Pbind(*base)));
},

logPairing: { |self, p, what|
	var e = self.synths[p[\synth]];
	if (p[\hash].notNil) {
		self.appendLine(self.patternDir(p[\name]) +/+ "pairings.jsonl", self.jsonEncode((time: self.isoNow,
			event: what, synth: p[\synth], synthHash: e !? { e[\hash] }, patternHash: p[\hash])));
	};
	self.broadcast('/ps/event/pattern', p[\name], if (what == \stop) { 0 } { 1 }, p[\synth],
		(e !? { e[\hash] }) ? "", p[\hash] ? "");
},

// A pattern file evaluates to a Pattern. Its synth is the pattern's own \instrument if it sets one,
// else `synth`, else the previous binding. Returns a result Event.
definePattern: { |self, name, path, synth, infoJson, save = true|
	var res = (name: name, ok: false, errors: List[], warnings: List[]);
	var src, ev, pat, fixed, binding, err, p, wasPlaying, keys = Set[], logId = UniqueID.next;
	name = name.asSymbol;
	synth = synth !? (_.asSymbol);
	block { |break|
		var fail = { |stage, msg| res[\stage] = stage; res[\errors].add(msg); break.value };
		if (self.validName(name).not) {
			fail.(\name, "invalid name '%': letters, digits and _, starting with a letter, not starting with ps_".format(name))
		};
		src = self.readFile(path);
		if (src.isNil) { fail.(\read, "can't read %".format(path)) };
		if (infoJson.notNil and: { infoJson.size > 0 } and: { (try { infoJson.parseJSON } { nil }).isNil }) {
			fail.(\info, "info is not valid JSON")
		};

		res[\logId] = logId;
		self.logMark("begin", logId);
		ev = self.evalSource(src);
		if (ev[\ok] and: { ev[\value].isKindOf(Pattern).not }) {
			ev = (ok: false, stage: \evaluate, error: "pattern code must evaluate to a Pattern such as Pbind(...), got %".format(ev[\value].class.name))
		};
		if (ev[\ok]) {
			pat = ev[\value];
			err = try {
				var first = pat.asStream.next(Event.default);
				if (first.notNil and: { first.keys.includes(\instrument) }) { fixed = first[\instrument].asSymbol };
				binding = fixed ?? { synth } ?? { self.patterns[name] !? { |old| old[\synth] } };
				if (binding.notNil and: { self.synths[binding].notNil }) {
					var str = Pchain(pat, Pbind(\instrument, binding)).asStream;
					16.do { str.next(Event.default) !? { |x| keys.addAll(x.keys) } };
				};
				nil
			} { |x| self.errorText(x) };
			if (err.notNil) { ev = (ok: false, stage: \evaluate, error: err) };
		};
		self.logMark("end", logId);
		if (ev[\ok].not) { fail.(ev[\stage], ev[\error]) };

		if (binding.isNil) { fail.(\bind, "pattern needs a synth: pass one, or set \\instrument in the pattern") };
		if (self.synths[binding].isNil) { fail.(\bind, "unknown synth '%'".format(binding)) };
		if (self.synths[binding][\kind] == \fx) { fail.(\bind, "'%' is an fx and can't be played by a pattern".format(binding)) };
		if (fixed.notNil and: { synth.notNil } and: { fixed != synth }) {
			res[\warnings].add("pattern sets \\instrument %, so synth % is ignored".format(fixed, synth))
		};

		wasPlaying = self.patternPlaying(name);
		keys.remove(\instrument);
		p = (name: name, synth: binding, userPattern: pat, overrides: IdentityDictionary(),
			keys: keys, fixed: fixed.notNil);
		p[\hash] = if (save) { self.saveSource(self.patternDir(name), "pattern.scd", src, infoJson) } { self.fileHash(path) };
		self.patterns[name] = p;
		if (save) { self.writePatternMeta(p) };
		self.updatePdef(p);
		res[\warnings].addAll(self.keyCheck(p, self.synths[binding]));
		if (wasPlaying) { self.logPairing(p, \play) };
		res.putAll((ok: true, synth: binding, hash: p[\hash], keys: keys.asArray.sort));
	};

	res[\errors] = res[\errors].reject(_.isNil).asArray;
	res[\warnings] = res[\warnings].asArray;
	if (res[\ok]) {
		if (save) { self.broadcast('/ps/event/defined', \pattern, name, p[\hash]) };
		if (res[\warnings].notEmpty) { self.log("pattern % warnings: %".format(name, res[\warnings].join("; "))) };
	} {
		self.log("pattern % failed at %: %".format(name, res[\stage], res[\errors].join("; ")));
		if (save and: { src.notNil }) { self.archiveFailure(name, src, res) };
	};
	res
},

// a quick pattern driven by /ps/pattern/set keys (degree, dur, octave, legato, scale, root); not saved
defaultPattern: { |self, name, synth|
	var e = self.synthEntry(synth), p;
	name = name.asSymbol;
	if (self.validName(name).not) { Error("invalid pattern name '%'".format(name)).throw };
	if (e[\kind] == \fx) { Error("'%' is an fx and can't be played by a pattern".format(synth)).throw };
	p = (name: name, synth: e[\name], overrides: IdentityDictionary(), keys: Set[], fixed: false);
	self.patternDefaults.keysValuesDo { |k, v| self.putOverride(p, k, v) };
	self.patterns[name] = p;
	self.updatePdef(p);
	(ok: true, name: name, synth: e[\name])
},

playPattern: { |self, name, synth|
	var p = self.patternEntry(name), e;
	if (synth.notNil and: { synth.asSymbol != p[\synth] }) {
		if (p[\fixed]) { Error("pattern '%' sets \\instrument itself, so it can't be rebound".format(name)).throw };
		e = self.synthEntry(synth);
		if (e[\kind] == \fx) { Error("'%' is an fx and can't be played by a pattern".format(synth)).throw };
		p[\synth] = e[\name];
		if (p[\hash].notNil) { self.writePatternMeta(p) };
		self.updatePdef(p);
		if (self.patternPlaying(name)) { self.logPairing(p, \play) };
	};
	e = self.synthEntry(p[\synth]);
	if (self.patternPlaying(name).not) {
		Pdef(self.pdefKey(p[\name])).play(TempoClock.default, quant: 1);
		self.logPairing(p, \play);
	};
	(ok: true, name: p[\name], synth: p[\synth], warnings: self.keyCheck(p, e))
},

stopPattern: { |self, name|
	var p = self.patternEntry(name);
	if (self.patternPlaying(p[\name])) {
		Pdef(self.pdefKey(p[\name])).stop;
		self.logPairing(p, \stop);
	};
	(ok: true)
},

// OSC values -> a stream: one value repeats, several make a loop; r/rest = rest,
// strings that compile to a Pattern are used as patterns, scale takes a Scale name
patternValue: { |self, key, vals|
	var err;
	var conv = vals.collect { |v|
		var sym = if (v.isNumber) { nil } { v.asSymbol }, ev;
		case
		{ v.isNumber } { v }
		{ #[r, rest].includes(sym) } { Rest() }
		{ key == \scale } { Scale.at(sym) ?? { err = "unknown scale '%'".format(v); nil } }
		{
			ev = self.evalSource(v.asString);
			if (ev[\ok] and: { ev[\value].isKindOf(Pattern) or: { ev[\value].isNumber } }) { ev[\value] } {
				err = "can't use '%' as a value for %".format(v, key); nil
			}
		}
	};
	if (err.notNil) { Error(err).throw };
	if (conv.size == 1) { Pn(conv[0], inf) } { Pseq(conv, inf) }
},

putOverride: { |self, p, key, vals|
	var pdefn = Pdefn(("ps_pat_" ++ p[\name] ++ "_" ++ key).asSymbol);
	pdefn.source = self.patternValue(key, vals);
	p[\overrides][key] = pdefn;
	p[\keys].add(key);
},

// overrides a key on top of the pattern (not saved; the pattern file is unchanged)
setPatternKey: { |self, name, key, vals|
	var p = self.patternEntry(name), isNew;
	if (vals.isEmpty) { Error("pattern/set needs at least one value").throw };
	key = key.asSymbol;
	isNew = p[\overrides][key].isNil;
	self.putOverride(p, key, vals);
	if (isNew) { self.updatePdef(p) };
	(ok: true, warnings: self.keyCheck(p, self.synthEntry(p[\synth])))
},

patternState: { |self, name|
	var p = self.patternEntry(name);
	(ok: true, name: p[\name], synth: p[\synth], hash: p[\hash], playing: self.patternPlaying(p[\name]),
		keys: p[\keys].asArray.sort, overrides: p[\overrides].keys.asArray.sort, fixedInstrument: p[\fixed])
},

// after a synth is redefined: rebuild its patterns, check keys, log new pairings for playing ones
followSynth: { |self, name|
	var warnings = List[];
	self.patterns.do { |p|
		if (p[\synth] == name) {
			self.updatePdef(p);
			warnings.addAll(self.keyCheck(p, self.synths[name]));
			if (self.patternPlaying(p[\name])) { self.logPairing(p, \play) };
		}
	};
	warnings
}
)
