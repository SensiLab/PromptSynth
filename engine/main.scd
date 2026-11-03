// PromptSynth engine: boots scsynth, loads the synth library and serves the OSC API.
//
// SC IDE:   evaluate this file (or "/path/to/engine/main.scd".load)
// Headless: sclang engine/main.scd
//
// Re-running it replaces the running engine. Server options (device, memSize...)
// only take effect on a fresh server boot.
(
var root = thisProcess.nowExecutingPath.dirname;
var ps;

~promptSynth !? { |old| old.stopEngine };

ps = (root: root);
ps.config = (root +/+ "config.scd").load;
["util", "validate", "library", "players", "patterns", "channels", "recorder", "watch", "history", "osc", "core"].do { |mod|
	ps.putAll((root +/+ "lib" +/+ mod ++ ".scd").load)
};

ps.libraryDir = ("PS_LIBRARY_DIR".getenv ?? { ps.config[\libraryDir] } ?? { root.dirname +/+ "library" }).standardizePath;
"PS_OUT_DEVICE".getenv !? { |dev| ps.config[\outDevice] = dev };

ps.assertKeys;
~promptSynth = ps;
ps.startEngine;

// PS_VIEWS=1 / PS_UI=1 (tools/start-engine.sh --views / --ui): open the analysis views
// (engine/views.scd) and UI 2 (engine/ui2.scd) once the engine is ready
[["PS_VIEWS", "views.scd"], ["PS_UI", "ui2.scd"]].do { |pair|
	if (pair[0].getenv.notNil) {
		{ ps.waitFor(60, { ps.isReady == true }); { (root +/+ pair[1]).load }.defer }.fork(SystemClock)
	}
};
)
