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
["util", "validate", "library", "players", "patterns", "channels", "recorder", "watch", "osc", "core"].do { |mod|
	ps.putAll((root +/+ "lib" +/+ mod ++ ".scd").load)
};

ps.libraryDir = ("PS_LIBRARY_DIR".getenv ?? { ps.config[\libraryDir] } ?? { root.dirname +/+ "library" }).standardizePath;
"PS_OUT_DEVICE".getenv !? { |dev| ps.config[\outDevice] = dev };

ps.assertKeys;
~promptSynth = ps;
ps.startEngine;

// PS_VIEWS=1 (tools/start-engine.sh --views): open the analysis views (engine/views.scd) once ready
if ("PS_VIEWS".getenv.notNil) {
	{ ps.waitFor(60, { ps.isReady == true }); { (root +/+ "views.scd").load }.defer }.fork(SystemClock)
};
)
