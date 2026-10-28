// Boot, node tree, internal SynthDefs, status.
//
// Node order: default group | inputs (ps_input, then mappers) | sources (instances, pattern notes,
//             then fx at the tail) | tests | master (limiter) | recorder
(
engineVersion: "0.2.0",

startEngine: { |self|
	var server, o, c = self.config;
	// PS_SERVER_PORT runs a separate scsynth (tests, or next to an IDE server)
	"PS_SERVER_PORT".getenv !? { |port|
		Server.default = Server(\promptSynth, NetAddr("127.0.0.1", port.asInteger));
	};
	server = Server.default;
	o = server.options;
	self.server = server;
	self.synths = IdentityDictionary();
	self.patterns = IdentityDictionary();
	self.subscribers = List[];
	self.startedAt = self.isoNow;

	o.numOutputBusChannels = 2;
	o.numInputBusChannels = c[\numInputs];
	o.memSize = c[\memSize];
	o.numWireBufs = c[\numWireBufs];
	c[\outDevice] !? { |d| o.outDevice = d };
	c[\inDevice] !? { |d| o.inDevice = d };
	c[\sampleRate] !? { |sr| o.sampleRate = sr };
	TempoClock.default.tempo = c[\tempo] / 60;

	server.waitForBoot({
		self.setupChannels;
		self.addInternalDefs;
		server.sync;
		self.masterBus = Bus.audio(server, 2);
		self.buildTree;
		// brackets: reading a function-valued key with dot syntax would call it
		// Cmd-period also stops the watch routine, so it restarts here
		self[\treeFunc] = { self.buildTree; self.startWatch };
		ServerTree.add(self[\treeFunc], server);
		server.sync;
		self.loadLibrary;
		self.restoreState;
		self.startOSC;
		self.startWatch;
		self.isReady = true;
		self.log("ready engine=% langPort=% library=%".format(self.engineVersion, NetAddr.langPort, self.libraryDir));
		self.broadcast('/ps/event/ready', NetAddr.langPort);
	}, onFailure: { self.log("ERROR: server failed to boot") });
},

stopEngine: { |self|
	self.stopOSC;
	self.stopWatch;
	self[\treeFunc] !? { |f| ServerTree.remove(f, self.server) };
	self.patterns.do { |p| Pdef(self.pdefKey(p[\name])).stop };
	self.synths.do { |e| e[\buses].do(_.free) };
	self.channels.do { |ch| if (ch[\source] == \osc) { ch[\bus].free } };
	self.inputBus !? (_.free);
	if (self.server.serverRunning) {
		[self.inputGroup, self.sourceGroup, self.testGroup, self.masterGroup].do { |g| g !? (_.free) };
	};
	self.masterBus !? (_.free);
	self.isReady = false;
	self.log("stopped");
},

// also runs after Cmd-period, which frees every node
buildTree: { |self|
	var server = self.server;
	self.inputGroup = Group.after(server.defaultGroup);
	self.sourceGroup = Group.after(self.inputGroup);
	self.testGroup = Group.after(self.sourceGroup);
	self.masterGroup = Group.after(self.testGroup);
	self.masterSynth = Synth.head(self.masterGroup, \ps_master, [
		\bus, self.masterBus, \amp, self.config[\masterAmp], \ceiling, self.config[\masterCeilingDb].dbamp
	]);
	self.synths.do { |e| e[\instance] = nil };
	self.startInputs;
},

addInternalDefs: { |self|
	SynthDef(\ps_master, { |bus, out = 0, amp = 1, ceiling = 0.9|
		var sig = In.ar(bus, 2);
		sig = Sanitize.ar(LeakDC.ar(sig));
		sig = Limiter.ar(sig * amp.lag(0.05), ceiling, 0.01);
		Out.ar(out, sig);
	}).add;

	// channel (0..1) -> param bus; warp 0 lin, 1 exp, 2 curve, 3 amp
	SynthDef(\ps_mapper, { |in, out, min = 0, max = 1, warp = 0, curve = 0, lag = 0.02|
		var x = In.kr(in).clip(0, 1);
		var value = Select.kr(warp, [
			min + ((max - min) * x),
			min * ((max / min) ** x),
			min + ((max - min) * ((1 - (curve * x).exp) / (1 - curve.exp))),
			min + ((max - min) * x.squared)
		]);
		ReplaceOut.kr(out, value.lag(lag));
	}).add;

	// noise bursts to feed fx during their smoke test
	SynthDef(\ps_testsource, { |out, dur = 2|
		var bursts = WhiteNoise.ar([0.25, 0.25]) * Decay2.ar(Impulse.ar(4), 0.002, 0.15);
		Out.ar(out, bursts * EnvGen.kr(Env.linen(0, dur, 0), doneAction: 2));
	}).add;

	// sends peak, mean square and a NaN/inf flag after `dur` seconds
	SynthDef(\ps_analyzer, { |in, dur = 2, id = 0|
		var sig = In.ar(in, 2);
		var peak = Peak.ar(sig).reduce(\max);
		var bad = Peak.ar(CheckBadValues.ar(sig, 0, 0).inRange(1, 2)).reduce(\max);
		var meanSquare = Integrator.ar(sig.squared.sum * 0.5) / (SampleRate.ir * dur);
		var done = Line.kr(0, 1, dur) >= 1;
		SendReply.kr(done, '/ps_analysis', [A2K.kr(peak), A2K.kr(meanSquare), A2K.kr(bad)], id);
		Line.kr(0, 1, dur + 0.1, doneAction: 2);
	}).add;
},

pingInfo: { |self|
	(ok: true, engine: self.engineVersion, startedAt: self.startedAt, version: Main.version,
		langPort: NetAddr.langPort, ready: self.isReady == true)
},

statusInfo: { |self|
	var server = self.server, byName = { |a, b| a[\name].asString < b[\name].asString }, mappings = List[];
	self.synths.do { |e| e[\mappings].keysValuesDo { |k, m| mappings.add((synth: e[\name], param: k, channel: m[\channel])) } };
	(ok: true, ready: self.isReady == true, engine: self.engineVersion, startedAt: self.startedAt,
		server: server.serverRunning, sampleRate: server.sampleRate, cpu: server.avgCPU.round(0.1),
		numSynths: server.numSynths, langPort: NetAddr.langPort, tempo: TempoClock.default.tempo * 60,
		masterAmp: self.config[\masterAmp], recording: self.recPath, libraryDir: self.libraryDir,
		synths: self.synths.values.asArray.sort(byName).collect { |e|
			(name: e[\name], kind: e[\kind], hash: e[\hash], playing: e[\instance].notNil)
		},
		patterns: self.patterns.values.asArray.sort(byName).collect { |p|
			(name: p[\name], synth: p[\synth], hash: p[\hash], playing: self.patternPlaying(p[\name]))
		},
		mappings: mappings.asArray)
}
)
