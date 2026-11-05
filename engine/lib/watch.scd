// Reloads what's playing when its library file is saved over. Every watchInterval seconds this
// checks File.mtime of the pattern.scd of each playing pattern, its synth's synthdef.scd, and the
// synthdef.scd of each playing synth instance. A file whose content differs from the loaded
// version goes through the same define path as at boot, without saving: no new version, no
// history line, no meta, and no smoke test, so a live edit is heard at once. Files of things that
// aren't playing are checked as soon as they start.
(
watchInterval: 0.5,

watchTargets: { |self|
	var synths = List[], patterns = List[], target = { |kind, name, path|
		(kind: kind, name: name, path: path, label: "% %".format(kind, name))
	};
	var addSynth = { |name| if (synths.any { |t| t[\name] == name }.not) {
		synths.add(target.(\synth, name, self.synthDir(name) +/+ "synthdef.scd"))
	} };
	self.synths.do { |e| if (e[\instance].notNil) { addSynth.(e[\name]) } };
	self.patterns.do { |p|
		if (self.patternPlaying(p[\name])) {
			addSynth.(p[\synth]);
			patterns.add(target.(\pattern, p[\name], self.patternDir(p[\name]) +/+ "pattern.scd"));
		}
	};
	// synths first, so a pattern that changed with its synth is rebuilt on the new one
	(synths ++ patterns).select { |t| File.exists(t[\path]) }
},

loadedHash: { |self, t|
	if (t[\kind] == \synth) { self.synths[t[\name]] !? { |e| e[\hash] } } { self.patterns[t[\name]] !? { |p| p[\hash] } }
},

watchTick: { |self|
	var targets = self.watchTargets, labels = targets.collect(_[\label]);
	labels.reject { |l| self[\watched].includesEqual(l) }.do { |l| self.log("watch: watching %".format(l)) };
	self[\watched].reject { |l| labels.includesEqual(l) }.do { |l| self.log("watch: stopped watching %".format(l)) };
	self[\watched] = labels;
	targets.do { |t|
		var mtime = File.mtime(t[\path]);
		// mtimes are whole seconds: a second save in the same second looks unchanged, so while a
		// file was written in the last 2 seconds its content is compared on every tick
		if (mtime != self[\watchMtimes][t[\path]] or: { Date.getDate.rawSeconds - mtime < 2 }) {
			self[\watchMtimes][t[\path]] = mtime;
			if (self.fileHash(t[\path]) != self.loadedHash(t)) { self.watchReload(t) };
		}
	}
},

watchReload: { |self, t|
	var res;
	self.log("watch: % changed, reloading".format(t[\label]));
	res = if (t[\kind] == \synth) {
		self.runDefine(t[\name], t[\path], nil, (save: false, smoke: false))
	} {
		self.definePattern(t[\name], t[\path], nil, nil, false)
	};
	if (res[\ok]) {
		self.log("watch: reloaded % (%)".format(t[\label], res[\hash]))
	} {
		self.log("watch: % didn't reload, see the error above".format(t[\label]))
	};
	// a save made while this ran: the next tick compares the content again, whatever the mtime
	self[\watchMtimes][t[\path]] = nil;
},

// call again after Cmd-period, which stops every routine
startWatch: { |self|
	self.stopWatch;
	self[\watched] = [];
	self[\watchMtimes] = Dictionary();
	self[\watchRoutine] = Routine {
		loop {
			try { self.watchTick } { |err| self.log("watch: " ++ self.errorText(err)) };
			self.watchInterval.wait;
		}
	}.play(SystemClock);
},

stopWatch: { |self|
	self[\watchRoutine] !? { |r| r.stop };
	self[\watchRoutine] = nil;
}
)
