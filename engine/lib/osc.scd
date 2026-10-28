// The OSC API (see engine/README.md). Commands come in on sclang's port (57120 by default).
// Results go back to the sender as /ps/result <command> <json>; state changes go to
// subscribers as /ps/event/<type> ...args.
(
// path -> [handler(args, addr), alwaysReply]. Handlers return a result Event, or nil when
// they reply later themselves. Other commands only reply when they fail.
oscCommands: { |self|
	var name = { |args| args[0] ?? { Error("missing name").throw } };
	(
		'/ps/ping': [{ self.pingInfo }, true],
		'/ps/status': [{ self.statusInfo }, true],
		'/ps/subscribe': [{ |args, addr|
			var sub = NetAddr(addr.ip, args[0] ?? { addr.port });
			if (self.subscribers.any { |a| a == sub }.not) { self.subscribers.add(sub) };
			(ok: true)
		}, true],
		'/ps/unsubscribe': [{ |args, addr|
			var sub = NetAddr(addr.ip, args[0] ?? { addr.port });
			self.subscribers.removeAllSuchThat { |a| a == sub };
			(ok: true)
		}, true],

		'/ps/synth/define': [{ |args, addr|
			self.defineSynth(name.(args).asSymbol, (args[1] ?? { Error("missing path").throw }).asString,
				args[2] !? (_.asString), { |res| self.reply(addr, '/ps/synth/define', res) });
			nil
		}, true],
		'/ps/synth/play': [{ |args| self.playSynth(name.(args)) }, false],
		'/ps/synth/release': [{ |args| self.releaseSynth(name.(args)) }, false],

		'/ps/param/set': [{ |args| self.setParam(name.(args), args[1], args[2] ?? { Error("missing value").throw }) }, false],
		'/ps/param/norm': [{ |args| self.setParamNorm(name.(args), args[1], args[2] ?? { Error("missing value").throw }) }, false],
		'/ps/param/get': [{ |args| self.paramState(name.(args)) }, true],

		// /ps/pattern/define name path [synth] [infoJson]: an arg starting with { is the info
		'/ps/pattern/define': [{ |args|
			var rest = args.drop(2).collect(_.asString), info = rest.detect { |a| a.beginsWith("{") };
			var synth = rest.detect { |a| a.beginsWith("{").not and: { a.size > 0 } };
			self.definePattern(name.(args), (args[1] ?? { Error("missing path").throw }).asString,
				synth !? (_.asSymbol), info)
		}, true],
		'/ps/pattern/default': [{ |args| self.defaultPattern(name.(args), args[1] ?? { Error("missing synth").throw }) }, true],
		'/ps/pattern/play': [{ |args| self.playPattern(name.(args), args[1]) }, true],
		'/ps/pattern/stop': [{ |args| self.stopPattern(name.(args)) }, false],
		'/ps/pattern/set': [{ |args| self.setPatternKey(name.(args), args[1], args.drop(2)) }, false],
		'/ps/pattern/get': [{ |args| self.patternState(name.(args)) }, true],

		'/ps/channel/set': [{ |args| self.channelSet(name.(args), args[1] ?? { Error("missing value").throw }) }, false],
		'/ps/channel/list': [{ self.channelList }, true],
		// /ps/map synth param channel [min max] [warp]
		'/ps/map': [{ |args|
			var warp = args[5] ?? { if (args[3].notNil and: { args[3].isNumber.not }) { args[3] } };
			var range = if (args[3].isNumber) { [args[3], args[4]] } { [nil, nil] };
			self.mapParam(name.(args), args[1] ?? { Error("missing param").throw },
				args[2] ?? { Error("missing channel").throw }, range[0], range[1], warp)
		}, true],
		'/ps/unmap': [{ |args| self.unmapParam(name.(args), args[1] ?? { Error("missing param").throw }) }, true],

		'/ps/tempo': [{ |args| self.setTempo(args[0] ?? { Error("missing bpm").throw }) }, false],
		'/ps/master/amp': [{ |args| self.setMasterAmp(args[0] ?? { Error("missing amp").throw }) }, false],
		'/ps/panic': [{ self.panic }, false],

		'/ps/rec/start': [{ |args|
			// /ps/rec/start [name] [dur]: a lone number is a duration
			if (args[0].isNumber) { self.startRec(nil, args[0]) } { self.startRec(args[0], args[1]) }
		}, true],
		'/ps/rec/stop': [{ self.stopRec }, true],

		'/ps/library/reload': [{ |args, addr|
			{ self.reply(addr, '/ps/library/reload', self.loadLibrary) }.fork(SystemClock);
			nil
		}, true]
	)
},

startOSC: { |self|
	self.stopOSC;
	self.commands = self.oscCommands;
	self.oscDefs = self.commands.keys.asArray.collect { |path|
		var handler = self.commands[path][0], alwaysReply = self.commands[path][1];
		OSCdef(("ps" ++ path.asString.tr($/, $_)).asSymbol, { |msg, time, addr|
			// Run on the scheduler, not inside OSC dispatch: when other OSC recv funcs are
			// installed (OSCFunc.trace, monitoring quarks), an exception caught during dispatch
			// corrupts sclang's stack ("Message 'put' not understood" on a random object).
			SystemClock.sched(0, {
				var res = try { handler.value(msg.drop(1), addr) } { |err| (ok: false, errors: [self.errorText(err)]) };
				if (res.notNil) {
					if (res[\ok].not) { self.log("% failed: %".format(path, res[\errors].join("; "))) };
					if (alwaysReply or: { res[\ok].not }) { self.reply(addr, path, res) };
				};
				nil
			})
		}, path).permanent_(true)    // OSCdefs are removed on Cmd-period otherwise
	};
},

stopOSC: { |self|
	self.oscDefs.do(_.free);
	self.oscDefs = nil;
},

reply: { |self, addr, path, res|
	addr.sendMsg('/ps/result', path.asString.drop(4), self.jsonEncode(res));
},

broadcast: { |self, path ...args|
	self.subscribers.do { |a| a.sendMsg(path, *args) };
}
)
