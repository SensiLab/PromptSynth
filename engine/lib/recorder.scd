// Recording the master output (post limiter) to WAV.
// With a synth or pattern name the file goes to its recordings/ folder, otherwise library/_recordings/.
(
startRec: { |self, name, dur|
	var server = self.server, dir, path;
	if (server.isRecording) { Error("already recording to %".format(self.recPath)).throw };
	name = name !? (_.asSymbol);
	dir = case
		{ name.isNil } { self.libraryDir +/+ "_recordings" }
		{ self.synths[name].notNil } { self.synthDir(name) +/+ "recordings" }
		{ self.patterns[name].notNil } { self.patternDir(name) +/+ "recordings" }
		{ Error("unknown synth or pattern '%'".format(name)).throw };
	File.mkdir(dir);
	path = dir +/+ (name ? "master").asString ++ "_" ++ self.timestamp ++ ".wav";
	server.recHeaderFormat = self.config[\recHeaderFormat];
	server.recSampleFormat = self.config[\recSampleFormat];
	dur = dur !? { |d| d.asFloat.clip(0.1, 3600) };
	server.record(path, 0, 2, nil, dur);
	self.recPath = path;
	self.broadcast('/ps/event/rec', 1, path);
	dur !? { |d|
		SystemClock.sched(d + 0.5, { if (self.recPath == path) { self.recFinished(path) }; nil })
	};
	(ok: true, path: path, dur: dur)
},

stopRec: { |self|
	var path = self.recPath;
	if (path.isNil) { Error("not recording").throw };
	self.server.stopRecording;
	self.recFinished(path);
	(ok: true, path: path)
},

recFinished: { |self, path|
	self.recPath = nil;
	self.broadcast('/ps/event/rec', 0, path);
}
)
