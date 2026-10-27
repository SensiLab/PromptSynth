// Playing synths. Each control-rate param has a control bus; instances and pattern events
// are mapped to those buses, so one /ps/param/set drives both.
(
// keys the default Event computes itself; never bus-mapped in patterns
eventKeys: #[freq, midinote, note, degree, octave, root, scale, dur, legato, sustain, stretch,
	detune, harmonic, ctranspose, mtranspose, gtranspose, lag, timingOffset, tempo, db,
	instrument, group, out],

patternDefaults: { |self|
	(degree: [0, 2, 4, 7], dur: [0.25], octave: [5], legato: [0.8], scale: [\major], root: [0])
},

synthEntry: { |self, name|
	self.synths[name.asSymbol] ?? { Error("unknown synth '%'; define it first".format(name)).throw }
},

paramOf: { |self, e, key|
	e[\params].detect { |p| p[\name] == key.asSymbol }
		?? { Error("'%' has no param '%' (params: %)".format(e[\name], key, e[\params].collect(_[\name]))).throw }
},

registerEntry: { |self, def, kind, source, params, channels, hasGate|
	var name = def.name.asSymbol, old = self.synths[name], e;
	e = (name: name, kind: kind, source: source, def: def, params: params, channels: channels, hasGate: hasGate,
		buses: old !? { old[\buses] } ?? { IdentityDictionary() },
		paramValues: old !? { old[\paramValues] } ?? { IdentityDictionary() },
		instance: old !? { old[\instance] },
		patternKeys: old !? { old[\patternKeys] },
		userPattern: old !? { old[\userPattern] });

	e[\buses].keys.copy.do { |k|
		if (params.any { |p| p[\name] == k and: { p[\rate] == \control } }.not) { e[\buses].removeAt(k).free }
	};
	e[\paramValues].keys.copy.do { |k|
		if (params.any { |p| p[\name] == k }.not) { e[\paramValues].removeAt(k) }
	};
	params.do { |p|
		var k = p[\name], v = e[\paramValues][k];
		if (p[\rate] != \array) {
			v = if (v.isNil) { p[\default] } { p[\spec].constrain(v) };
			e[\paramValues][k] = v;
			if (p[\rate] == \control) {
				e[\buses][k] = e[\buses][k] ?? { Bus.control(self.server, 1) };
				e[\buses][k].set(v);
			}
		}
	};
	self.synths[name] = e;

	// hot-swap: a running instance restarts on the new definition
	if (e[\instance].notNil) { self.playSynth(name) };
	if (e[\patternKeys].notNil) { self.updatePdef(e) };
	e
},

instanceArgs: { |self, e|
	var args = [\out, self.masterBus.index];
	if (e[\kind] == \fx) { args = args ++ [\in, self.masterBus.index] };
	e[\params].do { |p|
		var k = p[\name];
		case
		{ p[\rate] == \control } { args = args ++ [k, e[\buses][k].asMap] }
		{ #[scalar, trigger, audio].includes(p[\rate]) } { args = args ++ [k, e[\paramValues][k]] }
	};
	args
},

playSynth: { |self, name|
	var e = self.synthEntry(name), syn;
	e[\instance] !? { |old| self.stopInstance(e, old) };
	// fx go last in the source group so they process everything before them
	syn = if (e[\kind] == \fx) { Synth.tail(self.sourceGroup, e[\name], self.instanceArgs(e)) } {
		Synth.head(self.sourceGroup, e[\name], self.instanceArgs(e))
	};
	if (e[\kind] != \oneshot) {
		e[\instance] = syn;
		syn.onFree {
			var cur = self.synths[e[\name]];
			if (cur.notNil and: { cur[\instance] === syn }) {
				cur[\instance] = nil;
				self.broadcast('/ps/event/synth', e[\name], 0);
			}
		};
	} {
		e[\instance] = nil;
	};
	self.broadcast('/ps/event/synth', e[\name], 1);
	(ok: true)
},

releaseSynth: { |self, name|
	var e = self.synthEntry(name);
	e[\instance] !? { |syn| self.stopInstance(e, syn) };
	(ok: true)
},

stopInstance: { |self, e, syn| if (e[\hasGate]) { syn.set(\gate, 0) } { syn.free } },

setParam: { |self, name, key, value|
	var e = self.synthEntry(name), p = self.paramOf(e, key);
	if (p[\rate] == \array) { Error("'%' is an array param and can't be set".format(key)).throw };
	value = p[\spec].constrain(value.asFloat);
	e[\paramValues][p[\name]] = value;
	case
	{ p[\rate] == \control } { e[\buses][p[\name]].set(value) }
	{ e[\instance].notNil } { e[\instance].set(p[\name], value) };
	self.broadcast('/ps/event/param', e[\name], p[\name], value);
	(ok: true, value: value)
},

// 0..1 from faders/controllers, mapped through the param's spec
setParamNorm: { |self, name, key, norm|
	var e = self.synthEntry(name), p = self.paramOf(e, key);
	self.setParam(name, key, p[\spec].map(norm.asFloat.clip(0, 1)))
},

paramState: { |self, name|
	var e = self.synthEntry(name);
	(ok: true, name: e[\name], kind: e[\kind], playing: e[\instance].notNil,
		values: e[\paramValues],
		params: e[\params].collect { |p| (name: p[\name], rate: p[\rate], spec: self.specJSON(p[\spec])) })
},

// --- patterns ---

pdefKey: { |self, name| ("ps_" ++ name).asSymbol },

ensurePattern: { |self, e|
	if (e[\patternKeys].isNil) {
		e[\patternKeys] = IdentityDictionary();
		self.patternDefaults.keysValuesDo { |k, v| self.putPatternKey(e, k, v) };
		self.updatePdef(e);
	}
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

putPatternKey: { |self, e, key, vals|
	var pdefn = Pdefn(("ps_" ++ e[\name] ++ "_" ++ key).asSymbol);
	pdefn.source = self.patternValue(key, vals);
	e[\patternKeys][key] = pdefn;
},

updatePdef: { |self, e|
	var name = e[\name], pairs, inner;
	var base = [\instrument, name, \out, Pfunc { self.masterBus.index }, \group, Pfunc { self.sourceGroup }];
	e[\params].do { |p|
		var k = p[\name];
		if (self.eventKeys.includes(k).not) {
			case
			{ p[\rate] == \control } { base = base ++ [k, e[\buses][k].asMap] }
			{ #[scalar, trigger].includes(p[\rate]) } { base = base ++ [k, Pfunc { e[\paramValues][k] }] }
		}
	};
	pairs = e[\patternKeys].keys.asArray.sort.collect { |k| [k, e[\patternKeys][k]] }.flatten;
	inner = case
		{ e[\userPattern].isNil } { Pbind(*pairs) }
		{ pairs.isEmpty } { e[\userPattern] }
		{ Pbindf(e[\userPattern], *pairs) };
	Pdef(self.pdefKey(name), Pchain(inner, Pbind(*base)));
},

playPattern: { |self, name|
	var e = self.synthEntry(name);
	if (e[\kind] == \fx) { Error("'%' is an fx; play it with /ps/synth/play".format(name)).throw };
	self.ensurePattern(e);
	Pdef(self.pdefKey(e[\name])).play(TempoClock.default, quant: 1);
	self.broadcast('/ps/event/pattern', e[\name], 1);
	(ok: true)
},

stopPattern: { |self, name|
	var e = self.synthEntry(name);
	Pdef(self.pdefKey(e[\name])).stop;
	self.broadcast('/ps/event/pattern', e[\name], 0);
	(ok: true)
},

setPatternKey: { |self, name, key, vals|
	var e = self.synthEntry(name), isNew;
	if (vals.isEmpty) { Error("pattern/set needs at least one value").throw };
	self.ensurePattern(e);
	key = key.asSymbol;
	isNew = e[\patternKeys][key].isNil;
	self.putPatternKey(e, key, vals);
	if (isNew) { self.updatePdef(e) };
	(ok: true)
},

patternPlaying: { |self, name| Pdef.all[self.pdefKey(name)] !? { |p| p.isPlaying } ? false },

// a pattern file evaluates to a Pattern; the engine adds \instrument, buses and output
definePattern: { |self, name, path, save = true|
	var e = self.synthEntry(name), src = self.readFile(path), ev, err, logId = UniqueID.next;
	if (src.isNil) { Error("can't read %".format(path)).throw };
	self.logMark("begin", logId);
	ev = self.evalSource(src);
	if (ev[\ok] and: { ev[\value].isKindOf(Pattern).not }) {
		ev = (ok: false, stage: \evaluate, error: "pattern code must evaluate to a Pattern such as Pbind(...), got %".format(ev[\value].class.name))
	};
	if (ev[\ok]) {
		err = try {
			var str = Pchain(ev[\value], Pbind(\instrument, e[\name])).asStream;
			16.do { str.next(Event.default) };
			nil
		} { |x| self.errorText(x) };
		if (err.notNil) { ev = (ok: false, stage: \evaluate, error: err) };
	};
	self.logMark("end", logId);
	if (ev[\ok]) {
		e[\userPattern] = ev[\value];
		e[\patternKeys] = IdentityDictionary();
		self.updatePdef(e);
		if (save) { self.saveVersioned(e[\name], "pattern.scd", src) };
		(ok: true, name: e[\name], logId: logId)
	} {
		self.log("pattern for % failed: %".format(e[\name], ev[\error]));
		(ok: false, name: e[\name], stage: ev[\stage], errors: [ev[\error]], logId: logId)
	}
},

setTempo: { |self, bpm|
	bpm = bpm.asFloat.clip(10, 400);
	TempoClock.default.tempo = bpm / 60;
	self.broadcast('/ps/event/tempo', bpm);
	(ok: true, bpm: bpm)
},

setMasterAmp: { |self, amp|
	amp = amp.asFloat.clip(0, 2);
	self.config[\masterAmp] = amp;
	self.masterSynth.set(\amp, amp);
	self.broadcast('/ps/event/master', amp);
	(ok: true, amp: amp)
},

panic: { |self|
	self.synths.do { |e|
		Pdef(self.pdefKey(e[\name])).stop;
		if (e[\instance].notNil) { e[\instance] = nil; self.broadcast('/ps/event/synth', e[\name], 0) };
	};
	self.sourceGroup.freeAll;
	self.broadcast('/ps/event/panic');
	(ok: true)
}
)
