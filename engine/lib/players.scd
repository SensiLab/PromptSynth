// Playing synths. Each control-rate param has a control bus; instances and pattern events
// are mapped to those buses, so one /ps/param/set (or a mapping) drives both.
(
synthEntry: { |self, name|
	self.synths[name.asSymbol] ?? { Error("unknown synth '%'; define it first".format(name)).throw }
},

// without it, plays look fine and every note goes to a dead server
requireServer: { |self|
	if (self.server.serverRunning.not) { Error("server is not running").throw }
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
		mappings: old !? { old[\mappings] } ?? { IdentityDictionary() },
		instance: old !? { old[\instance] },
		hash: old !? { old[\hash] });

	// drop buses, values and mappings of params this version no longer has
	e[\mappings].keys.copy.do { |k|
		if (params.any { |p| p[\name] == k and: { p[\rate] == \control } }.not) {
			e[\mappings].removeAt(k)[\node].free
		}
	};
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
	self.requireServer;
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
	self.saveStateSoon;
	// while mapped, the channel drives the bus; this value applies again when unmapped
	(ok: true, value: value, mappedTo: e[\mappings][p[\name]] !? { |m| m[\channel] })
},

// 0..1 from faders/controllers, mapped through the param's spec
setParamNorm: { |self, name, key, norm|
	var e = self.synthEntry(name), p = self.paramOf(e, key);
	self.setParam(name, key, p[\spec].map(norm.asFloat.clip(0, 1)))
},

paramState: { |self, name|
	var e = self.synthEntry(name), mappings = ();
	e[\mappings].keysValuesDo { |k, m| mappings[k] = (channel: m[\channel], min: m[\min], max: m[\max], warp: m[\warp]) };
	(ok: true, name: e[\name], kind: e[\kind], hash: e[\hash], playing: e[\instance].notNil,
		values: e[\paramValues], mappings: mappings,
		params: e[\params].collect { |p| (name: p[\name], rate: p[\rate], spec: self.specJSON(p[\spec])) })
},

setTempo: { |self, bpm|
	bpm = bpm.asFloat.clip(10, 400);
	TempoClock.default.tempo = bpm / 60;
	self.broadcast('/ps/event/tempo', bpm);
	self.saveStateSoon;
	(ok: true, bpm: bpm)
},

setMasterAmp: { |self, amp|
	amp = amp.asFloat.clip(0, 2);
	self.config[\masterAmp] = amp;
	self.masterSynth.set(\amp, amp);
	self.broadcast('/ps/event/master', amp);
	self.saveStateSoon;
	(ok: true, amp: amp)
},

panic: { |self|
	self.patterns.keys.do { |name| if (self.patternPlaying(name)) { self.stopPattern(name, true) } };
	self.synths.do { |e|
		if (e[\instance].notNil) { e[\instance] = nil; self.broadcast('/ps/event/synth', e[\name], 0) };
	};
	self.sourceGroup.freeAll;
	self.broadcast('/ps/event/panic');
	(ok: true)
}
)
