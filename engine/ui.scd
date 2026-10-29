// PromptSynth UI v1. Runs in the engine's sclang: evaluate this file once the engine is up
// (engine/main.scd). Evaluating it again replaces the open UI; it reopens itself after an
// engine restart and survives Cmd-period.
//
// Main window: synths and patterns with play/stop (button or double-click), the selected one's
// trail (its versions and what each changed, from history.jsonl), an event log (newest first)
// and a master meter. "analysis" opens a second window with a freq scope and scope of the output.
//
// It uses the engine's public functions and listens to /ps/event/* like any subscriber. It shows
// no params and no control channel values: the code is the interface. Nothing in here may block
// (no shell commands, no file reads per frame): the pattern clock shares this interpreter.
(
var ps = ~promptSynth, uiPath = thisProcess.nowExecutingPath;
~promptSynthUI !? { |old| old[\close].value };
if (ps.isNil or: { ps.isReady != true }) {
	"[ps-ui] the engine isn't ready: evaluate engine/main.scd first".postln;
} {
	var win, header, synthList, patternList, trail, logView, meters, analysis, poller, probe, meterSynth;
	var status, selected, trailHash, logLines = List[], oscDefs = List[], lastStall = 0, closed = false;
	var font = Font.monospace(12), small = Font.monospace(11);
	var addLog, label, setItems, refresh, showTrail, toggle, startMeter, startProbe, treeFunc, openAnalysis, close;

	addLog = { |str|
		{
			logLines.addFirst(Date.getDate.format("%H:%M:%S  ") ++ str);
			if (logLines.size > 300) { logLines.pop };
			if (closed.not) { logView.string = logLines.join("\n") };
		}.defer
	};

	label = { |playing, name, rest|
		var n = name.asString;
		(if (playing) { "▶ " } { "  " }) ++ n ++ String.fill((18 - n.size).max(1), $ ) ++ rest
	};

	// only touch a list when its contents change, so the selection stays put
	setItems = { |view, items, playing|
		var v = view.value;
		if (items != view.items) {
			view.items = items;
			view.colors = playing.collect { |p| if (p) { Color(0.78, 0.93, 0.78) } { Color.white } };
			if (v.notNil and: { v < items.size }) { view.value = v };
		}
	};

	refresh = {
		var st, entry;
		if (~promptSynth !== ps) {
			// the engine was restarted: reopen on the new one
			win.close;
			if (uiPath.notNil) {
				{
					var done = false;
					60.do { if (done.not) {
						if (~promptSynth.notNil and: { ~promptSynth.isReady == true }) { done = true; { uiPath.load }.defer } { 1.wait }
					} };
				}.fork(SystemClock);
			};
		} {
			st = ps.statusInfo;
			status = st;
			header.string = "engine %    server %    CPU %    % BPM    master %".format(st[\engine],
				if (st[\server]) { "running" } { "NOT RUNNING" }, st[\cpu].asString ++ "%", st[\tempo].round(0.1), st[\masterAmp]);
			setItems.(synthList, st[\synths].collect { |s| label.(s[\playing], s[\name], s[\kind]) }, st[\synths].collect(_[\playing]));
			setItems.(patternList, st[\patterns].collect { |p| label.(p[\playing], p[\name], "→ " ++ p[\synth]) }, st[\patterns].collect(_[\playing]));
			// a new version (or a watched save) of the selected item: reread its trail
			if (selected.notNil) {
				entry = st[if (selected[0] == \synth) { \synths } { \patterns }].detect { |e| e[\name] == selected[1] };
				if (entry.notNil and: { entry[\hash] != trailHash }) { showTrail.() };
			};
		}
	};

	// reads the item's history once, on selection or when its loaded version changes
	showTrail = {
		var kind = selected[0], name = selected[1], dir, lines, entry, info, prev, out = List[], seen = false;
		var lastStep = { |p| var i = p.findBackwards(" / "); if (i.isNil) { p } { p.drop(i + 3) } };
		dir = if (kind == \synth) { ps.synthDir(name) } { ps.patternDir(name) };
		entry = status !? { status[if (kind == \synth) { \synths } { \patterns }].detect { |e| e[\name] == name } };
		trailHash = entry !? { entry[\hash] };
		lines = (ps.readFile(dir +/+ "history.jsonl") ? "").split($\n).reject(_.isEmpty)
			.collect { |l| try { l.parseJSON } { nil } }.reject(_.isNil);
		lines.do { |h|
			var prompt = h["info"] !? { |i| if (i.isKindOf(Dictionary)) { i["prompt"] } }, step;
			step = case
				{ prompt.isNil } { "(no prompt)" }
				{ prev.notNil and: { prompt.beginsWith(prev) } and: { prompt.size > prev.size } } {
					var r = prompt.drop(prev.size);
					if (r.beginsWith(" / ")) { r.drop(3) } { r }
				}
				{ lastStep.(prompt) };
			if (h["hash"] == trailHash) { seen = true };
			out.addFirst("% %  %  %".format(if (h["hash"] == trailHash) { "●" } { " " }, h["hash"],
				(h["time"] ? "").drop(5).keep(11).replace("T", " "), step));
			prompt !? { prev = prompt };
		};
		if (seen.not and: { trailHash.notNil }) {
			out.addFirst("● %  edited in place (refining the version below)".format(trailHash));
		};
		info = try { (ps.readFile(dir +/+ "info.json") ? "{}").parseJSON } { nil };
		if (info.isKindOf(Dictionary) and: { info["parent"].notNil }) { out.add("   copied from %".format(info["parent"])) };
		trail.string = "% %  (% versions)\n\n".format(kind, name, lines.size) ++ out.join("\n");
	};

	toggle = {
		var kind, name, entry;
		if (selected.notNil and: { status.notNil }) {
			#kind, name = selected;
			try {
				if (kind == \synth) {
					entry = status[\synths].detect { |s| s[\name] == name };
					if (entry[\playing]) { ps.releaseSynth(name) } { ps.playSynth(name) };
				} {
					entry = status[\patterns].detect { |p| p[\name] == name };
					if (entry[\playing]) {
						ps.stopPattern(name);
						addLog.("% stops at its next bar line".format(name));
					} { ps.playPattern(name) };
				};
			} { |err| addLog.("% %: %".format(kind, name, ps.errorText(err))) };
			refresh.();
		};
		nil
	};

	// level of what you hear: the hardware outs, after the master limiter
	startMeter = { if (ps.server.serverRunning) { meterSynth = Synth.tail(RootNode(ps.server), \ps_ui_meter) } };

	// the pattern clock waking up late means this interpreter was blocked; past the server
	// latency (0.2 s) notes play late
	startProbe = {
		probe.stop;
		probe = Routine {
			loop {
				var late = Main.elapsedTime - thisThread.seconds;
				if (late > 0.15 and: { Main.elapsedTime - lastStall > 1 }) {
					lastStall = Main.elapsedTime;
					addLog.("timing: clock woke % ms late (past 200 ms, notes play late)".format((late * 1000).round.asInteger));
				};
				0.25.wait;
			}
		}.play(TempoClock.default);
	};
	treeFunc = { startMeter.(); startProbe.() };   // after Cmd-period, which frees nodes and clears clocks

	openAnalysis = {
		if (analysis.notNil) { analysis[\win].front } {
			var w = Window("PromptSynth analysis", Rect(1080, 80, 640, 560)), fsv, scope;
			fsv = FreqScopeView(w, Rect(0, 0, 640, 300), ps.server).active_(true).inBus_(0);
			scope = Stethoscope(ps.server, 2, 0, view: CompositeView(w, Rect(0, 300, 640, 260)));
			w.onClose = { fsv.kill; scope.free; analysis = nil };
			analysis = (win: w);
			w.front;
		}
	};

	close = {
		if (closed.not) {
			closed = true;
			poller.stop;
			probe.stop;
			if (ps.server.serverRunning) { meterSynth !? (_.free) };
			oscDefs.do(_.free);
			ServerTree.remove(treeFunc, ps.server);
			NetAddr.localAddr.sendMsg('/ps/unsubscribe');
			analysis !? { analysis[\win].close };
			if (~promptSynthUI.notNil and: { ~promptSynthUI[\win] === win }) { ~promptSynthUI = nil };
		}
	};

	// --- views ---
	win = Window("PromptSynth", Rect(80, 80, 980, 660));
	header = StaticText().font_(Font.monospace(12, true));
	synthList = ListView().font_(font).fixedWidth_(330).selectionMode_(\single);
	patternList = ListView().font_(font).fixedWidth_(330).selectionMode_(\single);
	trail = TextView().font_(small).editable_(false);
	logView = TextView().font_(small).editable_(false).fixedHeight_(190);
	meters = 2.collect { LevelIndicator().drawsPeak_(true).warning_(0.8).critical_(0.95).fixedWidth_(16).fixedHeight_(190) };

	[[synthList, \synth], [patternList, \pattern]].do { |pair|
		var view = pair[0], kind = pair[1], other = if (kind == \synth) { patternList } { synthList };
		view.action = { |v|
			var names = status !? { status[if (kind == \synth) { \synths } { \patterns }].collect(_[\name]) };
			if (v.value.notNil and: { names.notNil } and: { v.value < names.size }) {
				other.value = nil;
				selected = [kind, names[v.value]];
				showTrail.();
			};
		};
		view.mouseDownAction = { |v, x, y, mod, button, clicks| if (clicks == 2) { toggle.() }; nil };
	};

	win.layout = VLayout(
		HLayout(header, nil,
			Button().states_([["play / stop"]]).action_({ toggle.() }),
			Button().states_([["panic"]]).action_({ ps.panic }),
			Button().states_([["analysis"]]).action_({ openAnalysis.() })),
		HLayout(
			VLayout(StaticText().string_("synths"), synthList, StaticText().string_("patterns"), patternList),
			VLayout(StaticText().string_("trail"), trail)),
		HLayout(VLayout(StaticText().string_("log"), logView), *meters)
	);
	win.onClose = { close.() };
	~promptSynthUI = (win: win, close: { win.close });

	// --- engine events ---
	[
		['/ps/event/log', { |m| addLog.(m[1].asString) }],
		['/ps/event/pattern', { |m| addLog.(if (m[2] == 1) { "▶ % on %".format(m[1], m[3]) } { "■ % stopped".format(m[1]) }) }],
		['/ps/event/synth', { |m| addLog.(if (m[2] == 1) { "▶ synth %".format(m[1]) } { "■ synth % released".format(m[1]) }) }],
		['/ps/event/defined', { |m| addLog.("new version: % % %".format(m[1], m[2], m[3])) }],
		['/ps/event/panic', { addLog.("panic: everything stopped") }]
	].do { |pair|
		oscDefs.add(OSCdef(("ps_ui" ++ pair[0].asString.tr($/, $_)).asSymbol, { |msg| pair[1].(msg) }, pair[0]).permanent_(true));
	};
	oscDefs.add(OSCdef(\ps_ui_meter, { |msg|
		{
			if (closed.not) {
				2.do { |i|
					meters[i].value = msg[4 + (i * 2)].ampdb.linlin(-60, 0, 0, 1);
					meters[i].peakLevel = msg[3 + (i * 2)].ampdb.linlin(-60, 0, 0, 1);
				}
			}
		}.defer
	}, '/ps_ui_meter', ps.server.addr).permanent_(true));
	NetAddr.localAddr.sendMsg('/ps/subscribe');

	{
		SynthDef(\ps_ui_meter, { SendPeakRMS.kr(In.ar(0, 2), 20, 3, '/ps_ui_meter') }).add;
		ps.server.sync;
		startMeter.();
	}.fork(AppClock);
	startProbe.();
	ServerTree.add(treeFunc, ps.server);
	poller = SkipJack({ refresh.() }, 0.25, { closed }, "ps-ui");

	refresh.();
	win.front;
	addLog.("UI open");
};
)
