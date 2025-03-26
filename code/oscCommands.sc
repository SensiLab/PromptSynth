(
var o = Server.local.options;
// o.outDevice = ServerOptions.devices[ServerOptions.devices.indexOfEqual("Soundflower (2ch)")];
o.outDevice = ServerOptions.devices[ServerOptions.devices.indexOfEqual("SERIES 208i")];
o.numOutputBusChannels = 2;

s.waitForBoot({

	var deinit = {
		Ndef(\synth).clear(fadeTime:4.3);
		onStart.free;
		onNext.free;
		onEnd.free;
		{s.quit}.defer(1);
	};

	var onStart = OSCFunc({ |msg, time, addr, recvPort|
		("start").postln;
		Ndef(\synth).fadeTime = 4;
		Ndef(\synth).play;
	}, '/start');

	var onNext = OSCFunc({ |msg, time, addr, recvPort|
		var path = PathName(msg[1].asString);
		var name = path.fileName.splitext[0];
		var file = File.new(path.asAbsolutePath,"r");
		var str = file.readAllString;
		// str.exceptionHandler = {|e| "eerroorr".post;e.postln;}; ? why does this not work ??
		// use interpretPrint (returns nill if error) instead of interpret (throws error)
		protect {
			str.interpret
		}{|error|
			"ERROR : ".post; // error not always being caught :(
			error.species.name.postln;
		}
		// ("running... "++name).postln;

	}, '/next');

	var onEnd = OSCFunc({ |msg, time, addr, recvPort|
		deinit.();
		("end").postln;
	}, '/end').oneShot;

	CmdPeriod.doOnce({ deinit.() });

	// s.scope(numChannels:2);
	// s.scope.style = 2;

	// FreqScope.new(400, 200, 0, server: s);
	// a = Spectrogram.new;
	// a.start;

});
)



