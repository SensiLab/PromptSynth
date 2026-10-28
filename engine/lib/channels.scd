// Control channels: live input on control buses. The ps_input synth writes the mouse, its button
// and the watched keys; OSC clients create channels with /ps/channel/set. A mapping connects a
// channel to a synth param's bus through a ps_mapper synth (range + warp). Channel values are
// input and never recorded; mappings are part of the orchestra and saved with the settings.
// Synths never read the mouse or keyboard themselves (the contract check rejects it).
(
// macOS virtual key codes (US layout)
keyCodeList: [[\a, 0], [\s, 1], [\d, 2], [\f, 3], [\h, 4], [\g, 5], [\z, 6], [\x, 7], [\c, 8],
	[\v, 9], [\b, 11], [\q, 12], [\w, 13], [\e, 14], [\r, 15], [\y, 16], [\t, 17], ['1', 18],
	['2', 19], ['3', 20], ['4', 21], ['6', 22], ['5', 23], ['9', 25], ['7', 26], ['8', 28],
	['0', 29], [\o, 31], [\u, 32], [\i, 34], [\p, 35], [\l, 37], [\j, 38], [\k, 40], [\n, 45],
	[\m, 46], [\space, 49]],

watchedKeys: { |self|
	var want = self.config[\keys];
	case
	{ want == \all } { self.keyCodeList }
	{ want.isNil } { [] }
	{ self.keyCodeList.select { |kv| want.includes(kv[0]) } }
},

// built-in channels: mouseX, mouseY (0 bottom .. 1 top), mouseButton, key_<name> (0/1)
setupChannels: { |self|
	var keys = self.watchedKeys;
	var names = [\mouseX, \mouseY, \mouseButton] ++ keys.collect { |kv| ("key_" ++ kv[0]).asSymbol };
	self.channels = IdentityDictionary();
	self.inputBus = Bus.control(self.server, names.size);
	names.do { |n, i|
		self.channels[n] = (name: n, source: if (i < 3) { \mouse } { \key },
			bus: Bus(\control, self.inputBus.index + i, 1, self.server))
	};
	SynthDef(\ps_input, { |out|
		Out.kr(out, [MouseX.kr(0, 1, 0, 0.05), MouseY.kr(0, 1, 0, 0.05), MouseButton.kr(0, 1, 0.01)]
			++ keys.collect { |kv| KeyState.kr(kv[1], 0, 1, 0.01) })
	}).add;
},

// OSC channels are created on first use (set or map)
oscChannel: { |self, name|
	var ch;
	name = name.asSymbol;
	ch = self.channels[name];
	if (ch.isNil) {
		if (self.validName(name).not) { Error("invalid channel name '%'".format(name)).throw };
		ch = (name: name, source: \osc, bus: Bus.control(self.server, 1));
		self.channels[name] = ch;
	};
	ch
},

channelSet: { |self, name, value|
	var ch = self.oscChannel(name);
	if (ch[\source] != \osc) { Error("'%' is a built-in % channel and can't be set".format(name, ch[\source])).throw };
	ch[\bus].set(value.asFloat);
	(ok: true)
},

channelList: { |self|
	(ok: true, channels: self.channels.values.asArray.sort { |a, b| a[\name].asString < b[\name].asString }
		.collect { |ch| (name: ch[\name], source: ch[\source]) })
},

// min/max/warp default to the param's spec; warp: lin, exp, amp or a curve number
mapParam: { |self, synth, param, channel, min, max, warp|
	var e = self.synthEntry(synth), p = self.paramOf(e, param), spec = p[\spec];
	var ch = self.oscChannel(channel), warnings = [], warpIndex, curve = 0, m;
	if (p[\rate] != \control) { Error("only control-rate params can be mapped; % is %".format(param, p[\rate])).throw };
	min = (min ?? { spec.minval }).asFloat;
	max = (max ?? { spec.maxval }).asFloat;
	warp = warp ?? { spec.warp.asSpecifier };
	warp = if (warp.isNumber) { warp } { warp.asSymbol };
	warpIndex = case
		{ warp.isNumber } { if (warp == 0) { 0 } { curve = warp; 2 } }
		{ #[exp, exponential].includes(warp) } {
			if ((min * max) > 0) { 1 } { warnings = warnings.add("exp needs min and max of the same sign, using lin"); 0 }
		}
		{ warp == \amp } { 3 }
		{ #[lin, linear].includes(warp).not } { warnings = warnings.add("unknown warp '%', using lin".format(warp)); 0 }
		{ 0 };
	e[\mappings][p[\name]] !? { |old| old[\node].free };
	m = (channel: ch[\name], min: min, max: max, warp: warp, warpIndex: warpIndex, curve: curve);
	e[\mappings][p[\name]] = m;
	self.startMapper(e, p[\name], m);
	self.broadcast('/ps/event/map', e[\name], p[\name], ch[\name], min, max, warp.asString);
	self.saveStateSoon;
	(ok: true, synth: e[\name], param: p[\name], channel: ch[\name], min: min, max: max, warp: warp, warnings: warnings)
},

startMapper: { |self, e, param, m|
	m[\node] = Synth.tail(self.inputGroup, \ps_mapper, [\in, self.channels[m[\channel]][\bus], \out, e[\buses][param],
		\min, m[\min], \max, m[\max], \warp, m[\warpIndex], \curve, m[\curve]]);
},

unmapParam: { |self, synth, param|
	var e = self.synthEntry(synth), p = self.paramOf(e, param), m = e[\mappings].removeAt(p[\name]);
	if (m.isNil) { Error("%.% isn't mapped".format(e[\name], p[\name])).throw };
	m[\node].free;
	e[\buses][p[\name]].set(e[\paramValues][p[\name]]);
	self.broadcast('/ps/event/map', e[\name], p[\name], "");
	self.saveStateSoon;
	(ok: true)
},

// after the node tree is rebuilt (boot, Cmd-period)
startInputs: { |self|
	self.inputSynth = Synth.head(self.inputGroup, \ps_input, [\out, self.inputBus]);
	self.synths.do { |e| e[\mappings].keysValuesDo { |k, m| self.startMapper(e, k, m) } };
}
)
