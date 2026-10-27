// Engine tests, driven through the OSC API. Silent: master amp is set to 0 first.
//
//   PS_LIBRARY_DIR=/tmp/ps-test-lib sclang engine/test/run_tests.scd
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

thisProcess.addOSCRecvFunc({ |msg| if (msg[0].asString.beginsWith("/ps/event/")) { events.add(msg) } });

(root.dirname +/+ "main.scd").load;
ps = ~promptSynth;
lib = ps.libraryDir;

tests = {
	var res, status, path;
	ps.waitFor(60, { ps.isReady == true });
	"\n=== PromptSynth engine tests (library: %) ===".format(lib).postln;

	res = request.('/ps/ping');
	check.("ping", truthy.(res["ok"]) and: { truthy.(res["ready"]) }, res);
	check.("subscribe", truthy.(request.('/ps/subscribe')["ok"]));
	send.('/ps/master/amp', 0);
	check.("master amp event", eventSeen.("master", 0.0) or: { eventSeen.("master", 0) });

	"-- define".postln;
	res = define.(\pad, "pad.scd", "{\"prompt\": \"warm \\\"saw\\\" pad\", \"tags\": [\"pad\"]}");
	check.("pad defines", truthy.(res["ok"]), res);
	check.("pad is sustained", res["kind"] == "sustained", res["kind"]);
	check.("pad has no warnings", res["warnings"].size == 0, res["warnings"]);
	check.("pad makes sound", res["peakDb"].asFloat > -40, res["peakDb"]);
	check.("pad cutoff spec from metadata", res["params"].detect { |p| p["name"] == "cutoff" } !? { |p| p["spec"]["min"].asFloat == 100 } ? false, res["params"]);
	check.("pad amp spec inferred", res["params"].detect { |p| p["name"] == "amp" } !? { |p| p["spec"]["max"].asFloat == 1 } ? false);
	check.("pad saved", File.exists(lib +/+ "pad/synthdef.scd") and: { File.exists(lib +/+ "pad/meta.json") });
	check.("pad info.json verbatim", File.exists(lib +/+ "pad/info.json") and: {
		File.readAllString(lib +/+ "pad/info.json").parseJSON["prompt"] == "warm \"saw\" pad" });
	check.("meta.json parses", File.readAllString(lib +/+ "pad/meta.json").parseJSON["kind"] == "sustained");
	check.("defined event", eventSeen.("defined", \pad));

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
	check.("failed synth not in library", File.exists(lib +/+ "broken").not);
	res = define.(\evalError, "eval_error.scd");
	check.("evaluate error", res["stage"] == "evaluate" and: { has.(res["errors"], "not understood") }, res);
	res = define.(\fixedBus, "fixed_bus.scd");
	check.("fixed bus rejected", res["stage"] == "contract" and: { has.(res["errors"], "fixed bus") }, res);
	res = define.(\multi, "multichannel.scd");
	check.("4 channels rejected", res["stage"] == "contract" and: { has.(res["errors"], "Splay") }, res);
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
	check.("status shows pad playing", status["synths"].detect { |s| s["name"] == "pad" } !? { |s| truthy.(s["playing"]) } ? false, status);
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
	check.("pad v2 defines", truthy.(res["ok"]), res);
	check.("old version kept", PathName(lib +/+ "pad/versions").files.size == 1);
	check.("value kept across redefine", request.('/ps/param/get', \pad)["values"]["cutoff"].asFloat == 8000);
	1.wait;
	status = request.('/ps/status');
	check.("still playing after hot swap", status["synths"].detect { |s| s["name"] == "pad" } !? { |s| truthy.(s["playing"]) } ? false, status);
	check.("one pad synth running", status["numSynths"].asInteger <= 4, status["numSynths"]);

	res = define.(\pad, "pad.scd");
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
	check.("fx playing", status["synths"].detect { |s| s["name"] == "verb" } !? { |s| truthy.(s["playing"]) } ? false, status);
	// /g_queryTree.reply: [cmd, flag, groupID, numChildren, id, -1, defName, id, -1, defName...] for synths
	res = nil;
	OSCFunc({ |msg| res = msg }, '/g_queryTree.reply', ps.server.addr).oneShot;
	ps.server.sendMsg("/g_queryTree", ps.sourceGroup.nodeID, 0);
	ps.waitFor(2, { res.notNil });
	check.("fx is last in the source group", res.notNil and: { ps.synths[\verb][\instance].notNil } and: {
		res[res.size - 3] == ps.synths[\verb][\instance].nodeID }, res);
	send.('/ps/synth/release', \pad);
	res = send.('/ps/pattern/play', \verb);
	check.("fx can't play patterns", res.notNil and: { has.(res["errors"], "is an fx") }, res);
	send.('/ps/synth/release', \verb);
	3.wait;
	check.("fx release frees it", eventSeen.("synth", \verb, 0));
	send.('/ps/synth/play', \perc);

	"-- patterns".postln;
	check.("pattern set", send.('/ps/pattern/set', \pad, \degree, 0, 2, \r, 4).isNil);
	send.('/ps/pattern/play', \pad);
	1.wait;
	status = request.('/ps/status');
	check.("pattern playing", status["synths"].detect { |s| s["name"] == "pad" } !? { |s| truthy.(s["pattern"]) } ? false, status);
	res = send.('/ps/pattern/set', \pad, \scale, \nope);
	check.("unknown scale errors", res.notNil and: { has.(res["errors"], "scale") }, res);
	check.("pattern code value", send.('/ps/pattern/set', \pad, \dur, "Pwhite(0.1, 0.3)").isNil);
	res = request.('/ps/pattern/define', \pad, fx.("pattern.scd"));
	check.("pattern define", truthy.(res["ok"]), res);
	check.("pattern saved", File.exists(lib +/+ "pad/pattern.scd"));
	res = request.('/ps/pattern/define', \pad, fx.("bad_pattern.scd"));
	check.("bad pattern rejected", truthy.(res["ok"]).not, res);
	1.wait;
	send.('/ps/pattern/stop', \pad);
	check.("pattern stop event", eventSeen.("pattern", \pad, 0));

	"-- recording".postln;
	res = request.('/ps/rec/start', \texture, 1);
	path = res["path"];
	check.("rec start", truthy.(res["ok"]) and: { path.asString.contains("texture/recordings") }, res);
	2.5.wait;
	check.("rec file written", path.notNil and: { File.exists(path) } and: { File.fileSize(path) > 1000 }, path !? { File.fileSize(path) });
	check.("rec end event", eventSeen.("rec", 0));
	res = request.('/ps/rec/stop');
	check.("rec stop when idle errors", truthy.(res["ok"]).not, res);

	"-- library".postln;
	res = request.('/ps/library/reload');
	check.("library reload", truthy.(res["ok"]) and: {
		#["pad", "perc", "texture", "silent", "noFree", "verb"].every { |n| res["loaded"].includesEqual(n) } }, res);
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
