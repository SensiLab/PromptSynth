// Turning a source file into a checked SynthDef: compile, evaluate, contract check, smoke test.
(
// stages: syntax -> evaluate -> contract -> server -> smoke
evalSource: { |self, str|
	var fn = thisProcess.interpreter.compile(str), value, err;
	if (fn.isNil) {
		(ok: false, stage: \syntax, error: "syntax error (see post window log)")
	} {
		value = try { fn.value } { |e| err = e; nil };
		if (err.notNil) {
			(ok: false, stage: \evaluate, error: self.errorText(err))
		} {
			(ok: true, value: value)
		}
	}
},

// a bare function becomes a gated, fading stereo SynthDef (like Ndef/Function:play)
wrapFunction: { |self, name, func|
	SynthDef(name, { |out = 0, gate = 1, fadeIn = 0.05, fadeOut = 1|
		var sig = SynthDef.wrap(func).asArray.flat;
		var env = EnvGen.kr(Env.asr(fadeIn, 1, fadeOut), gate, doneAction: 2);
		sig = sig.collect { |x| if (x.rate == \audio) { x } { K2A.ar(x) } };
		sig = case
			{ sig.size == 1 } { sig[0] ! 2 }
			{ sig.size > 2 } { Splay.ar(sig) }
			{ sig };
		Out.ar(out, sig * env)
	})
},

contractCheck: { |self, def|
	var errors = List[], warnings = List[];
	var names = def.allControlNames.collect { |cn| cn.name.asSymbol };
	var outs = def.children.select { |u| u.isKindOf(Out) or: { u.isKindOf(XOut) } };
	var channels = 0;

	if (names.includes(\out).not) {
		errors.add("needs an `out` argument, and must write to it with Out.ar(out, sig)")
	};
	if (outs.isEmpty) { errors.add("has no Out.ar, so it makes no sound") };
	def.children.select { |u| self.inputUGens.any { |c| u.isKindOf(c) } }.collect(_.class).asSet.do { |c|
		errors.add("reads %, but synths never read the mouse or keyboard: expose a param and map a control channel to it (/ps/map)".format(c.name))
	};
	outs.do { |u|
		var ch = u.inputs.size - (if (u.isKindOf(XOut)) { 2 } { 1 });
		channels = max(channels, ch);
		if (u.inputs[0].isNumber) {
			errors.add("writes to fixed bus %; use Out.ar(out, sig) so output goes through the master limiter".format(u.inputs[0]))
		};
		if (u.rate != \audio) { errors.add("uses %.kr; use Out.ar".format(u.class.name)) };
	};
	case
	{ channels > 2 } { errors.add("outputs % channels; reduce to stereo, e.g. Splay.ar(sig)".format(channels)) }
	{ channels == 1 } { warnings.add("mono output only plays on the left channel; use Pan2.ar or sig ! 2") };
	if (self.isFx(def) and: { names.includes(\in).not }) {
		warnings.add("fx has no `in` argument; read the mix with In.ar(in, 2)")
	};

	(errors: errors, warnings: warnings, channels: channels, hasGate: names.includes(\gate),
		kind: case
			{ self.isFx(def) } { \fx }
			{ names.includes(\gate) } { \sustained }
			{ \oneshot })
},

// input lives in control channels (lib/channels.scd), never inside a synth
inputUGens: [MouseX, MouseY, MouseButton, KeyState],

// fx: metadata (fx: true). Runs at the end of the source group, reads the mix from `in`
// and writes it back to `out` (usually with ReplaceOut)
isFx: { |self, def| (def.metadata !? { |m| m[\fx] }) == true },

// user-facing controls with specs; out and gate are managed by the engine
paramList: { |self, def|
	var specs = def.metadata !? { |m| m[\specs] } ?? { () };
	var managed = if (self.isFx(def)) { #[out, i_out, gate, in] } { #[out, i_out, gate] };
	def.allControlNames.reject { |cn| managed.includes(cn.name.asSymbol) }.collect { |cn|
		var name = cn.name.asSymbol, default = cn.defaultValue;
		if (default.isArray) {
			(name: name, rate: \array, default: default)
		} {
			(name: name, rate: cn.rate, default: default,
				spec: self.inferSpec(name, default, specs[name] ?? { specs[name.asString] }))
		}
	}
},

inferSpec: { |self, name, default, given|
	var str = name.asString.toLower, spec;
	var has = { |words| words.any { |w| str.contains(w) } };
	spec = given !? { given.asSpec };
	spec = spec ?? { Spec.specs[name] };
	spec = spec ?? {
		case
		{ has.(#["freq", "cutoff"]) } { \freq.asSpec }
		{ has.(#["amp", "vol", "level", "gain"]) } { \amp.asSpec }
		{ has.(#["pan"]) } { \pan.asSpec }
		{ has.(#["attack", "atk", "release", "rel", "decay", "fade", "time", "lag"]) } { ControlSpec(0.001, 10, \exp) }
		{ str == "rq" } { ControlSpec(0.05, 2, \exp) }
		{ has.(#["mix", "wet", "dry", "depth", "amount", "res", "feedback"]) or: { str == "q" } } { \unipolar.asSpec }
		{ has.(#["rate", "speed"]) } { ControlSpec(0.01, 50, \exp) }
	};
	// the synth's own default must be reachable, otherwise fall back to a plain linear range
	if (spec.isNil or: { default.inclusivelyBetween(spec.clipLo, spec.clipHi).not }) {
		spec = ControlSpec(min(0, default * 2), max(1, default * 4), \lin)
	} {
		spec = spec.copy
	};
	spec.default = default;
	spec
},

specJSON: { |self, spec|
	spec !? { (min: spec.minval, max: spec.maxval, warp: spec.warp.asSpecifier, step: spec.step,
		default: spec.default, units: spec.units) }
},

// plays the synth with default args on a private bus and measures it; call from a Routine.
// fx get noise bursts as input.
smokeTest: { |self, def, kind, hasGate|
	var server = self.server, dur = self.config[\smokeDur], id = UniqueID.next;
	var bus = Bus.audio(server, 2);
	var res = (errors: List[], warnings: List[], freed: false);
	var resp, syn, peak;

	resp = OSCFunc({ |msg|
		if (msg[2] == id) { res[\peak] = msg[3]; res[\meanSquare] = msg[4]; res[\bad] = msg[5] }
	}, '/ps_analysis', server.addr);
	Synth.tail(self.testGroup, \ps_analyzer, [\in, bus, \dur, dur, \id, id]);
	syn = if (kind == \fx) {
		Synth.after(Synth.head(self.testGroup, \ps_testsource, [\out, bus, \dur, dur]), def.name, [\out, bus, \in, bus])
	} {
		Synth.head(self.testGroup, def.name, [\out, bus])
	};
	syn.onFree { res[\freed] = true };

	self.waitFor(dur + 2, { res[\peak].notNil });
	case
	{ hasGate } { syn.set(\gate, 0) }
	{ kind == \fx } { syn.free; res[\freed] = true };
	self.waitFor(self.config[\releaseTimeout], { res[\freed] });
	if (res[\freed].not) { syn.free };
	resp.free;
	bus.free;

	if (res[\peak].isNil) {
		res[\errors].add("no analysis came back from the server (did the synth start?)");
	} {
		peak = res[\peak];
		res[\peakDb] = peak.ampdb.max(-200).round(0.1);
		res[\rmsDb] = res[\meanSquare].max(0).sqrt.ampdb.max(-200).round(0.1);
		if (res[\bad] > 0) { res[\errors].add("output contains NaN or inf values") };
		if (peak < 0.0001) {
			res[\warnings].add("silent with default arguments (peak % dBFS); check the envelope, gate and that it writes to `out`".format(res[\peakDb]))
		};
		if (peak > 1) { res[\warnings].add("clips: peak % dBFS; lower the level (aim for about -6 dBFS)".format(res[\peakDb])) };
		if (res[\rmsDb] > -6) { res[\warnings].add("very loud: RMS % dBFS".format(res[\rmsDb])) };
	};
	if (res[\freed].not) {
		res[\warnings].add(if (hasGate) {
			"did not free within %s of gate=0; use doneAction: 2 on the amplitude envelope".format(self.config[\releaseTimeout])
		} {
			"one-shot (no gate) still running after %s; give it a finite envelope with doneAction: 2, or add a gate argument".format(dur + self.config[\releaseTimeout])
		})
	};
	res
},

// Full pipeline. Returns a result Event; call from a Routine.
// opts: smoke (run the audio test), save (write to the library)
runDefine: { |self, name, path, infoJson, opts|
	var res = (name: name, ok: false, errors: List[], warnings: List[]);
	var src, ev, def, check, params, smoke, failures, failFn, logId, e;
	opts = (smoke: true, save: true).putAll(opts ? ());

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

		logId = UniqueID.next;
		res[\logId] = logId;
		self.logMark("begin", logId);
		ev = self.evalSource(src);
		if (ev[\ok]) {
			def = ev[\value];
			case
			{ def.isKindOf(SynthDef) } { def.name = name; res[\source] = \synthdef }
			{ def.isKindOf(Function) } {
				def = try { self.wrapFunction(name, def) } { |e| ev = (ok: false, stage: \evaluate, error: self.errorText(e)); nil };
				res[\source] = \function;
			}
			{ ev = (ok: false, stage: \evaluate,
				error: "code must evaluate to a SynthDef (without .add or .play) or a Function, got %".format(def.class.name)) };
		};
		self.logMark("end", logId);
		if (ev[\ok].not) { fail.(ev[\stage], ev[\error]) };

		check = self.contractCheck(def);
		res[\kind] = check[\kind];
		res[\channels] = check[\channels];
		res[\warnings].addAll(check[\warnings]);
		if (check[\errors].notEmpty) { res[\errors].addAll(check[\errors]); fail.(\contract, nil) };
		params = self.paramList(def);

		failures = List[];
		failFn = OSCFunc({ |msg| failures.add(msg.drop(1).join(" ")) }, '/fail', self.server.addr);
		def.add;
		self.server.sync;
		if (opts[\smoke]) {
			smoke = self.smokeTest(def, check[\kind], check[\hasGate]);
			res[\peakDb] = smoke[\peakDb];
			res[\rmsDb] = smoke[\rmsDb];
			res[\warnings].addAll(smoke[\warnings]);
			res[\errors].addAll(smoke[\errors]);
		};
		failFn.free;
		if (failures.notEmpty) { res[\errors].addAll(failures.collect("server: " ++ _)); fail.(\server, nil) };
		if (res[\errors].notEmpty) { fail.(\smoke, nil) };

		res[\ok] = true;
		res[\params] = params.collect { |p|
			(name: p[\name], rate: p[\rate], default: p[\default], spec: self.specJSON(p[\spec]))
		};
		e = self.registerEntry(def, check[\kind], res[\source], params, check[\channels], check[\hasGate]);
		e[\hash] = if (opts[\save]) { self.saveSynth(name, src, infoJson, res) } { self.fileHash(path) };
		res[\hash] = e[\hash];
		res[\warnings].addAll(self.followSynth(e[\name]));
	};

	res[\errors] = res[\errors].reject(_.isNil).asArray;
	res[\warnings] = res[\warnings].asArray;
	if (res[\ok]) {
		self.log("defined % (%%)%".format(name, res[\kind],
			res[\peakDb] !? { |db| ", peak % dBFS".format(db) } ? "",
			if (res[\warnings].notEmpty) { " warnings: " ++ res[\warnings].join("; ") } { "" }));
	} {
		self.log("define % failed at %: %".format(name, res[\stage], res[\errors].join("; ")));
		if (opts[\save] and: { src.notNil }) { self.archiveFailure(name, src, res) };
	};
	res
},

defineSynth: { |self, name, path, infoJson, action|
	// SystemClock: waits are in seconds whatever the tempo
	{
		var res = self.runDefine(name, path, infoJson);
		if (res[\ok]) { self.broadcast('/ps/event/defined', \synth, name, res[\hash]) };
		action.value(res);
	}.fork(SystemClock)
}
)
