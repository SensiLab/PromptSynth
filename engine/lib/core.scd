// Boot, node tree, internal SynthDefs, status.
//
// Node order: default group | sources (instances, pattern notes, then fx at the tail) | tests
//             | master (limiter) | recorder
(
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
	self.subscribers = List[];

	o.numOutputBusChannels = 2;
	o.numInputBusChannels = c[\numInputs];
	o.memSize = c[\memSize];
	o.numWireBufs = c[\numWireBufs];
	c[\outDevice] !? { |d| o.outDevice = d };
	c[\inDevice] !? { |d| o.inDevice = d };
	c[\sampleRate] !? { |sr| o.sampleRate = sr };
	TempoClock.default.tempo = c[\tempo] / 60;

	server.waitForBoot({
		self.addInternalDefs;
		server.sync;
		self.masterBus = Bus.audio(server, 2);
		self.buildTree;
		self.treeFunc = { self.buildTree };
		ServerTree.add(self.treeFunc, server);
		server.sync;
		self.loadLibrary;
		self.startOSC;
		self.isReady = true;
		self.log("ready langPort=% library=%".format(NetAddr.langPort, self.libraryDir));
		self.broadcast('/ps/event/ready', NetAddr.langPort);
	}, onFailure: { self.log("ERROR: server failed to boot") });
},

stopEngine: { |self|
	self.stopOSC;
	self.treeFunc !? { |f| ServerTree.remove(f, self.server) };
	self.synths.do { |e|
		Pdef(self.pdefKey(e[\name])).stop;
		e[\buses].do(_.free);
	};
	if (self.server.serverRunning) {
		[self.sourceGroup, self.testGroup, self.masterGroup].do { |g| g !? (_.free) };
	};
	self.masterBus !? (_.free);
	self.isReady = false;
	self.log("stopped");
},

// also runs after Cmd-period, which frees every node
buildTree: { |self|
	var server = self.server;
	self.sourceGroup = Group.after(server.defaultGroup);
	self.testGroup = Group.after(self.sourceGroup);
	self.masterGroup = Group.after(self.testGroup);
	self.masterSynth = Synth.head(self.masterGroup, \ps_master, [
		\bus, self.masterBus, \amp, self.config[\masterAmp], \ceiling, self.config[\masterCeilingDb].dbamp
	]);
	self.synths.do { |e| e[\instance] = nil };
},

addInternalDefs: { |self|
	SynthDef(\ps_master, { |bus, out = 0, amp = 1, ceiling = 0.9|
		var sig = In.ar(bus, 2);
		sig = Sanitize.ar(LeakDC.ar(sig));
		sig = Limiter.ar(sig * amp.lag(0.05), ceiling, 0.01);
		Out.ar(out, sig);
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

statusInfo: { |self|
	var server = self.server;
	(ok: true, ready: self.isReady == true, server: server.serverRunning,
		sampleRate: server.sampleRate, cpu: server.avgCPU.round(0.1), numSynths: server.numSynths,
		langPort: NetAddr.langPort, tempo: TempoClock.default.tempo * 60,
		masterAmp: self.config[\masterAmp], recording: self.recPath,
		libraryDir: self.libraryDir,
		synths: self.synths.values.asArray.sort { |a, b| a[\name].asString < b[\name].asString }.collect { |e|
			(name: e[\name], kind: e[\kind], playing: e[\instance].notNil, pattern: self.patternPlaying(e[\name]))
		})
}
)
