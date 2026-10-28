// Engine tests, driven through the OSC API. Silent: master amp is set to 0 first.
//
//   PS_SERVER_PORT=57140 PS_LIBRARY_DIR=/tmp/ps-test-lib sclang engine/test/run_tests.scd
//
// Use a throwaway library dir: the tests write and overwrite synths in it.
// Exits with the number of failed checks.
(
var root = thisProcess.nowExecutingPath.dirname;
var fx = { |file| root +/+ "fixtures" +/+ file };
var addr = NetAddr.localAddr;
var passes = 0, fails = List[], events = List[];
var ps, lib, tests;

var check = { |label, cond, info|
	if (cond == true) {
		passes = passes + 1;
		("  ok   " ++ label).postln;
	} {
		fails.add(label);
		("  FAIL " ++ label ++ (info !? { |i| " -> " ++ i.asString } ? "")).postln;
	}
};
var truthy = { |v| v.asString == "true" };
var has = { |list, str| list.asArray.any { |x| x.asString.contains(str) } };

// sends a command and waits for its /ps/result
var request = { |path ...args|
	var result, f = OSCFunc({ |msg| if (msg[1].asString == path.asString.drop(4)) { result = msg[2].asString.parseJSON } }, '/ps/result');
	addr.sendMsg(path, *args);
	ps.waitFor(30, { result.notNil });
	f.free;
	result ?? { () }
};
// fire-and-forget command; returns an error result if one comes back within `wait`
var send = { |path ...args|
	var result, f = OSCFunc({ |msg| result = msg[2].asString.parseJSON }, '/ps/result');
	addr.sendMsg(path, *args);
	0.3.wait;
	f.free;
	result
};
var eventSeen = { |type ...args|
	events.any { |msg| msg[0] == ("/ps/event/" ++ type).asSymbol and: { args.every { |a, i| msg[i + 1] == a } } }
};
var define = { |name, file, info| request.('/ps/synth/define', name, fx.(file), *(info !? { [info] } ? [])) };
var lines = { |path| (File.exists(path).if { File.readAllString(path) } { "" }).split($\n).reject(_.isEmpty) };
var busValue = { |bus| var v; bus.get { |x| v = x }; ps.waitFor(2, { v.notNil }); v };
var synthStatus = { |status, name| status["synths"].detect { |s| s["name"] == name.asString } ? () };
var patternStatus = { |status, name| status["patterns"].detect { |s| s["name"] == name.asString } ? () };
// how many nodes in the whole tree run this SynthDef
var countDef = { |defName| var r; OSCFunc({ |msg| r = msg }, '/g_queryTree.reply', ps.server.addr).oneShot;
	ps.server.sendMsg("/g_queryTree", 0, 0); ps.waitFor(2, { r.notNil }); r !? { r.occurrencesOf(defName) } };

thisProcess.addOSCRecvFunc({ |msg| if (msg[0].asString.beginsWith("/ps/event/")) { events.add(msg) } });

(root.dirname +/+ "main.scd").load;
ps = ~promptSynth;
lib = ps.libraryDir;

tests = {
	var res, status, path, padHash, v;
	ps.waitFor(60, { ps.isReady == true });
	"\n=== PromptSynth engine tests (library: %) ===".format(lib).postln;

	res = request.('/ps/ping');
	check.("ping", truthy.(res["ok"]) and: { truthy.(res["ready"]) }, res);
	check.("ping has engine version and start time", res["engine"] == ps.engineVersion and: { res["startedAt"].notNil }, res);
	check.("one master limiter and one input synth", countDef.('ps_master') == 1 and: { countDef.('ps_input') == 1 }, [countDef.('ps_master'), countDef.('ps_input')]);
	check.("subscribe", truthy.(request.('/ps/subscribe')["ok"]));
	send.('/ps/master/amp', 0);
	check.("master amp event", eventSeen.("master", 0.0) or: { eventSeen.("master", 0) });

	"-- define".postln;
	res = define.(\pad, "pad.scd", "{\"prompt\": \"warm \\\"saw\\\" pad\",\n \"tags\": [\"pad\"]}");
	padHash = res["hash"];
	check.("pad defines", truthy.(res["ok"]), res);
	check.("pad is sustained", res["kind"] == "sustained", res["kind"]);
	check.("pad has no warnings", res["warnings"].size == 0, res["warnings"]);
	check.("pad makes sound", res["peakDb"].asFloat > -40, res["peakDb"]);
	check.("pad cutoff spec from metadata", res["params"].detect { |p| p["name"] == "cutoff" } !? { |p| p["spec"]["min"].asFloat == 100 } ? false, res["params"]);
	check.("pad amp spec inferred", res["params"].detect { |p| p["name"] == "amp" } !? { |p| p["spec"]["max"].asFloat == 1 } ? false);
	check.("pad has a 12-char hash", padHash.asString.size == 12, padHash);
	check.("pad saved under synths/", File.exists(lib +/+ "synths/pad/synthdef.scd") and: { File.exists(lib +/+ "synths/pad/meta.json") });
	check.("version stored by hash", File.exists(lib +/+ "synths/pad/versions" +/+ padHash ++ ".scd"));
	check.("history line with info", lines.(lib +/+ "synths/pad/history.jsonl").size == 1 and: {
		lines.(lib +/+ "synths/pad/history.jsonl")[0].parseJSON["info"]["prompt"] == "warm \"saw\" pad" });
	check.("pad info.json verbatim", File.readAllString(lib +/+ "synths/pad/info.json").parseJSON["prompt"] == "warm \"saw\" pad");
	check.("meta.json has hash", File.readAllString(lib +/+ "synths/pad/meta.json").parseJSON["hash"] == padHash);
	check.("defined event with hash", eventSeen.("defined", \synth, \pad, padHash.asSymbol));

	res = define.(\perc, "perc.scd");
	check.("perc defines as oneshot", truthy.(res["ok"]) and: { res["kind"] == "oneshot" }, res);
	check.("perc frees itself", has.(res["warnings"], "free").not, res["warnings"]);

	res = define.(\texture, "texture.scd");
	check.("function texture defines", truthy.(res["ok"]) and: { res["source"] == "function" } and: { res["kind"] == "sustained" }, res);
	check.("texture params", res["params"].collect(_["name"]).asSet == Set["note", "width", "fadeIn", "fadeOut"], res["params"].collect(_["name"]));

	"-- define failures".postln;
	res = define.(\broken, "syntax.scd");
	check.("syntax error", truthy.(res["ok"]).not and: { res["stage"] == "syntax" }, res);
	check.("syntax failure archived", PathName(lib +/+ "_failed").files.any { |f| f.fileName.contains("broken") });
	check.("failed synth not in library", File.exists(lib +/+ "synths/broken").not);
	res = define.(\evalError, "eval_error.scd");
	check.("evaluate error", res["stage"] == "evaluate" and: { has.(res["errors"], "not understood") }, res);
	res = define.(\fixedBus, "fixed_bus.scd");
	check.("fixed bus rejected", res["stage"] == "contract" and: { has.(res["errors"], "fixed bus") }, res);
	res = define.(\multi, "multichannel.scd");
	check.("4 channels rejected", res["stage"] == "contract" and: { has.(res["errors"], "Splay") }, res);
	res = define.(\mouseSynth, "mouse_synth.scd");
	check.("mouse inside a synth rejected", res["stage"] == "contract" and: { has.(res["errors"], "MouseX") } and: { has.(res["errors"], "/ps/map") }, res);
	res = define.(\notDef, "not_synthdef.scd");
	check.("non-SynthDef rejected", res["stage"] == "evaluate" and: { has.(res["errors"], "Integer") }, res);
	res = define.(\nan, "nan.scd");
	check.("NaN detected", res["stage"] == "smoke" and: { has.(res["errors"], "NaN") }, res);
	res = define.(\silent, "silent.scd");
	check.("silent accepted with warning", truthy.(res["ok"]) and: { has.(res["warnings"], "silent") }, res);
	res = define.(\noFree, "no_free.scd");
	check.("missing doneAction warned", truthy.(res["ok"]) and: { has.(res["warnings"], "did not free") }, res);
	res = define.(\ps_x, "pad.scd");
	check.("reserved name rejected", res["stage"] == "name", res);
	res = define.('../evil', "pad.scd");
	check.("path-like name rejected", res["stage"] == "name", res);
	res = define.(\missing, "nope.scd");
	check.("missing file", res["stage"] == "read", res);

	"-- play and params".postln;
	send.('/ps/synth/play', \pad);
	check.("play event", eventSeen.("synth", \pad, 1));
	status = request.('/ps/status');
	check.("status shows pad playing", truthy.(synthStatus.(status, \pad)["playing"]), status);
	check.("param set", send.('/ps/param/set', \pad, \cutoff, 2000).isNil);
	check.("param event", eventSeen.("param", \pad, \cutoff, 2000.0));
	res = request.('/ps/param/get', \pad);
	check.("param get", res["values"]["cutoff"].asFloat == 2000, res);
	send.('/ps/param/norm', \pad, \cutoff, 0);
	check.("param norm maps through spec", request.('/ps/param/get', \pad)["values"]["cutoff"].asFloat == 100);
	send.('/ps/param/set', \pad, \cutoff, 99999);
	check.("param clipped to spec", request.('/ps/param/get', \pad)["values"]["cutoff"].asFloat == 8000);
	res = send.('/ps/param/set', \pad, \nope, 1);
	check.("unknown param errors", res.notNil and: { has.(res["errors"], "no param") }, res);
	res = send.('/ps/synth/play', \ghost);
	check.("unknown synth errors", res.notNil and: { has.(res["errors"], "unknown synth") }, res);

	"-- redefine while playing".postln;
	res = define.(\pad, "pad_v2.scd");
	check.("pad v2 defines with a new hash", truthy.(res["ok"]) and: { res["hash"] != padHash }, res);
	check.("both versions stored by hash", PathName(lib +/+ "synths/pad/versions").files.size == 2);
	check.("value kept across redefine", request.('/ps/param/get', \pad)["values"]["cutoff"].asFloat == 8000);
	1.wait;
	status = request.('/ps/status');
	check.("still playing after hot swap", truthy.(synthStatus.(status, \pad)["playing"]), status);
	check.("one pad synth running", status["numSynths"].asInteger <= 6, status["numSynths"]);

	res = define.(\pad, "pad.scd");
	check.("back to v1: same hash", res["hash"] == padHash, res["hash"]);
	check.("returning to a version doesn't duplicate it", PathName(lib +/+ "synths/pad/versions").files.size == 2);
	check.("history records the return", lines.(lib +/+ "synths/pad/history.jsonl").size == 3);
	check.("removed param value pruned", request.('/ps/param/get', \pad)["values"]["detune"].isNil);
	define.(\pad, "pad_v2.scd");

	send.('/ps/synth/release', \pad);
	1.wait;
	check.("release event", eventSeen.("synth", \pad, 0));

	"-- fx".postln;
	res = define.(\verb, "fx_verb.scd");
	check.("fx defines", truthy.(res["ok"]) and: { res["kind"] == "fx" }, res);
	check.("fx not silent (fed test bursts)", res["warnings"].size == 0, res["warnings"]);
	check.("fx `in` is engine-managed", res["params"].any { |p| p["name"] == "in" }.not, res["params"].collect(_["name"]));
	send.('/ps/synth/play', \verb);
	send.('/ps/synth/play', \pad);     // added at the head, after the fx was started
	status = request.('/ps/status');
	check.("fx playing", truthy.(synthStatus.(status, \verb)["playing"]), status);
	// /g_queryTree.reply: [cmd, flag, groupID, numChildren, id, -1, defName, id, -1, defName...] for synths
	res = nil;
	OSCFunc({ |msg| res = msg }, '/g_queryTree.reply', ps.server.addr).oneShot;
	ps.server.sendMsg("/g_queryTree", ps.sourceGroup.nodeID, 0);
	ps.waitFor(2, { res.notNil });
	check.("fx is last in the source group", res.notNil and: { ps.synths[\verb][\instance].notNil } and: {
		res[res.size - 3] == ps.synths[\verb][\instance].nodeID }, res);
	send.('/ps/synth/release', \pad);
	send.('/ps/synth/release', \verb);
	3.wait;
	check.("fx release frees it", eventSeen.("synth", \verb, 0));
	send.('/ps/synth/play', \perc);

	"-- patterns".postln;
	res = request.('/ps/pattern/default', \padDefault, \pad);
	check.("default pattern", truthy.(res["ok"]) and: { res["synth"] == "pad" }, res);
	check.("pattern set", send.('/ps/pattern/set', \padDefault, \degree, 0, 2, \r, 4).isNil);
	res = request.('/ps/pattern/play', \padDefault);
	check.("pattern play", truthy.(res["ok"]), res);
	1.wait;
	status = request.('/ps/status');
	check.("pattern playing", truthy.(patternStatus.(status, \padDefault)["playing"]), status);
	res = send.('/ps/pattern/set', \padDefault, \scale, \nope);
	check.("unknown scale errors", res.notNil and: { has.(res["errors"], "scale") }, res);
	check.("pattern code value", send.('/ps/pattern/set', \padDefault, \dur, "Pwhite(0.1, 0.3)").isNil);
	send.('/ps/pattern/stop', \padDefault);

	res = request.('/ps/pattern/define', \walk, fx.("pattern.scd"), \pad, "{\"prompt\": \"a walk\"}");
	check.("named pattern defines", truthy.(res["ok"]) and: { res["synth"] == "pad" } and: { res["hash"].asString.size == 12 }, res);
	check.("pattern keys", ["cutoff", "degree", "dur"].every { |k| res["keys"].includesEqual(k) }, res["keys"]);
	check.("pattern files", ["pattern.scd", "meta.json", "info.json", "history.jsonl"].every { |f| File.exists(lib +/+ "patterns/walk" +/+ f) });
	check.("pattern meta binds synth", File.readAllString(lib +/+ "patterns/walk/meta.json").parseJSON["synth"] == "pad");
	check.("defined event for pattern", eventSeen.("defined", \pattern, \walk, res["hash"].asSymbol));
	res = request.('/ps/pattern/play', \walk);
	0.5.wait;
	v = lines.(lib +/+ "patterns/walk/pairings.jsonl").collect(_.parseJSON);
	check.("pairing logged with both hashes", v.size == 1 and: { v[0]["event"] == "play" } and: {
		v[0]["synth"] == "pad" } and: { v[0]["synthHash"] == ps.synths[\pad][\hash] } and: { v[0]["patternHash"] == ps.patterns[\walk][\hash] }, v);
	check.("pattern event has both hashes", eventSeen.("pattern", \walk, 1, \pad, ps.synths[\pad][\hash].asSymbol, ps.patterns[\walk][\hash].asSymbol));

	res = request.('/ps/pattern/define', \badkey, fx.("pattern_badkey.scd"), \pad);
	check.("key check on define", truthy.(res["ok"]) and: { has.(res["warnings"], "woodTune") }, res);
	res = define.(\pad, "pad.scd");
	check.("key check when synth is redefined", has.(res["warnings"], "badkey") and: { has.(res["warnings"], "woodTune") }, res["warnings"]);
	v = lines.(lib +/+ "patterns/walk/pairings.jsonl").collect(_.parseJSON);
	check.("redefine under a playing pattern logs a new pairing", v.size == 2 and: { v[1]["synthHash"] == padHash }, v);

	res = request.('/ps/pattern/play', \walk, \perc);
	check.("rebind pattern to another synth", truthy.(res["ok"]) and: { res["synth"] == "perc" }, res);
	check.("rebind logged", lines.(lib +/+ "patterns/walk/pairings.jsonl").last.parseJSON["synth"] == "perc");
	check.("rebind saved in meta", File.readAllString(lib +/+ "patterns/walk/meta.json").parseJSON["synth"] == "perc");
	res = request.('/ps/pattern/play', \walk, \verb);
	check.("fx can't be played by a pattern", truthy.(res["ok"]).not and: { has.(res["errors"], "is an fx") }, res);
	res = request.('/ps/pattern/define', \fixedPat, fx.("pattern_fixed.scd"));
	check.("pattern's own \\instrument binds it", truthy.(res["ok"]) and: { res["synth"] == "perc" }, res);
	res = request.('/ps/pattern/play', \fixedPat, \pad);
	check.("pattern with \\instrument can't be rebound", truthy.(res["ok"]).not and: { has.(res["errors"], "rebound") }, res);
	res = request.('/ps/pattern/define', \orphan, fx.("pattern_badkey.scd"));
	check.("pattern without a synth rejected", res["stage"] == "bind", res);
	res = request.('/ps/pattern/define', \walk2, fx.("bad_pattern.scd"), \pad);
	check.("bad pattern rejected", truthy.(res["ok"]).not, res);
	res = request.('/ps/pattern/get', \walk);
	check.("pattern get", res["synth"] == "perc" and: { truthy.(res["playing"]) }, res);
	send.('/ps/pattern/stop', \walk);
	check.("pattern stop event", eventSeen.("pattern", \walk, 0));
	check.("stop logged", lines.(lib +/+ "patterns/walk/pairings.jsonl").last.parseJSON["event"] == "stop");
	request.('/ps/pattern/play', \walk, \pad);
	send.('/ps/pattern/stop', \walk);

	"-- channels and mappings".postln;
	res = request.('/ps/channel/list');
	check.("built-in channels", ["mouseX", "mouseY", "mouseButton", "key_a", "key_space"].every { |n|
		res["channels"].any { |c| c["name"] == n } }, res);
	res = send.('/ps/channel/set', \mouseX, 0.5);
	check.("built-in channel can't be set", res.notNil and: { has.(res["errors"], "built-in") }, res);
	check.("osc channel set", send.('/ps/channel/set', \fader1, 0.25).isNil);
	res = request.('/ps/map', \pad, \cutoff, \fader1);
	check.("map with the param's spec", truthy.(res["ok"]) and: { res["min"].asFloat == 100 } and: { res["max"].asFloat == 8000 } and: { res["warp"] == "exp" }, res);
	0.3.wait;
	v = busValue.(ps.synths[\pad][\buses][\cutoff]);
	check.("mapped bus follows channel (exp)", (v - (100 * (80 ** 0.25))).abs < 1, v);
	send.('/ps/channel/set', \fader1, 1);
	0.3.wait;
	check.("channel move reaches the param", (busValue.(ps.synths[\pad][\buses][\cutoff]) - 8000).abs < 1);
	res = request.('/ps/map', \pad, \amp, \fader2, 0, 0.5, \lin);
	send.('/ps/channel/set', \fader2, 0.5);
	0.3.wait;
	check.("map with explicit range (lin)", truthy.(res["ok"]) and: { (busValue.(ps.synths[\pad][\buses][\amp]) - 0.25).abs < 0.001 }, res);
	res = request.('/ps/param/get', \pad);
	check.("param get lists mappings", res["mappings"]["cutoff"]["channel"] == "fader1", res["mappings"]);
	send.('/ps/param/set', \pad, \cutoff, 500);
	0.2.wait;
	check.("mapped param ignores set while mapped", (busValue.(ps.synths[\pad][\buses][\cutoff]) - 8000).abs < 1);
	res = request.('/ps/unmap', \pad, \cutoff);
	0.2.wait;
	check.("unmap restores the recorded value", truthy.(res["ok"]) and: { (busValue.(ps.synths[\pad][\buses][\cutoff]) - 500).abs < 0.01 }, res);
	res = request.('/ps/map', \pad, \nope, \fader1);
	check.("map unknown param errors", truthy.(res["ok"]).not, res);
	res = request.('/ps/map', \pad, \cutoff, \mouseY, 200, 4000, \exp);
	check.("map to the mouse", truthy.(res["ok"]) and: { res["channel"] == "mouseY" }, res);
	status = request.('/ps/status');
	check.("status lists mappings", status["mappings"].size == 2, status["mappings"]);

	"-- Cmd-period".postln;
	CmdPeriod.run;
	1.wait;
	res = request.('/ps/ping');
	check.("OSC API survives Cmd-period", truthy.(res["ok"]), res);
	send.('/ps/channel/set', \fader2, 1);
	0.3.wait;
	check.("mappings rebuilt after Cmd-period", (busValue.(ps.synths[\pad][\buses][\amp]) - 0.5).abs < 0.001);
	res = nil;
	OSCFunc({ |msg| res = msg }, '/g_queryTree.reply', ps.server.addr).oneShot;
	ps.server.sendMsg("/g_queryTree", ps.masterGroup.nodeID, 0);
	ps.waitFor(2, { res.notNil });
	check.("master limiter rebuilt after Cmd-period", res.notNil and: { res.includes('ps_master') }, res);
	check.("still one master and one input synth", countDef.('ps_master') == 1 and: { countDef.('ps_input') == 1 }, [countDef.('ps_master'), countDef.('ps_input')]);

	"-- settings saved and restored".postln;
	ps.saveState;
	v = File.readAllString(ps.stateFile).parseJSON;
	check.("state file has values and mappings", v["synths"]["pad"]["mappings"]["amp"]["channel"] == "fader2" and: {
		v["synths"]["pad"]["values"]["cutoff"].asFloat == 500 }, v["synths"]["pad"]);
	request.('/ps/unmap', \pad, \amp);
	request.('/ps/unmap', \pad, \cutoff);
	send.('/ps/param/set', \pad, \cutoff, 3000);
	ps.restoreState;
	0.3.wait;
	res = request.('/ps/param/get', \pad);
	check.("restore brings back values and mappings", res["values"]["cutoff"].asFloat == 500 and: {
		res["mappings"]["amp"]["channel"] == "fader2" } and: { res["mappings"]["cutoff"]["channel"] == "mouseY" }, res);

	"-- recording".postln;
	res = request.('/ps/rec/start', \walk, 1);
	path = res["path"];
	check.("rec start for a pattern", truthy.(res["ok"]) and: { path.asString.contains("patterns/walk/recordings") }, res);
	2.5.wait;
	check.("rec file written", path.notNil and: { File.exists(path) } and: { File.fileSize(path) > 1000 }, path !? { File.fileSize(path) });
	check.("rec end event", eventSeen.("rec", 0));
	res = request.('/ps/rec/stop');
	check.("rec stop when idle errors", truthy.(res["ok"]).not, res);

	"-- library".postln;
	res = request.('/ps/library/reload');
	check.("library reload", truthy.(res["ok"]) and: {
		#["pad", "perc", "texture", "silent", "noFree", "verb", "pattern walk", "pattern badkey", "pattern fixedPat"].every { |n|
			res["loaded"].includesEqual(n) } }, res);
	check.("reloaded pattern keeps its binding", ps.patterns[\walk][\synth] == \pad, ps.patterns[\walk][\synth]);
	send.('/ps/panic');
	check.("panic event", eventSeen.("panic"));

};

{
	try { tests.value } { |err| err.reportError; fails.add("EXCEPTION: " ++ err.errorString) };
	"\n=== % passed, % failed ===".format(passes, fails.size).postln;
	if (fails.notEmpty) { ("failed: " ++ fails.join(", ")).postln };
	Server.default.quit;
	1.wait;
	fails.size.min(255).exit;
}.fork(SystemClock);
)
