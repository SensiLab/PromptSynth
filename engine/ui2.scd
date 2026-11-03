// PromptSynth UI 2: the other side of the conversation. Claude Code is prompted in a terminal;
// this window shows what that does: what's playing (start / stop), what Claude Code is doing
// right now (prompt, thinking, reading, searching, writing, running...) and the engine's activity.
// The selected item's trail (its versions and what each changed) and the history player (step
// through what played; latest puts the newest versions back) work as in engine/ui.scd.
// `tools/start-engine.sh --ui` opens it at boot; or evaluate this file once the engine is up.
// Evaluating it again replaces it; it reopens itself after an engine restart.
//
// Claude Code activity arrives as OSC /cc/event (event kind detail), sent by the project's hooks
// (.claude/settings.json -> tools/cc-hook.mjs) to this sclang's port. Engine activity comes from
// /ps/event/* like any subscriber. Nothing in here may block (no shell commands, no file reads):
// the pattern clock shares this interpreter.
(
var ps = ~promptSynth, uiPath = thisProcess.nowExecutingPath;
~promptSynthUI2 !? { |old| old[\close].value };
if (ps.isNil or: { ps.isReady != true }) {
	"[ps-ui2] the engine isn't ready: evaluate engine/main.scd first".postln;
} {
	var win, header, patternList, synthList, ccState, ccDetail, ccPrompt, ccClock, ccFeed, logView;
	var status, selected, updating = false, closed = false, poller, oscDefs = List[];
	var trail, trailHash, historyList, historyLabel, steps = [], stepIndex, hidden = 0;
	var showTrail, showHistory, stepLines, loadStep, toLatest;
	var feedLines = List[], logLines = List[], ccKind = "idle", ccSince = Main.elapsedTime, promptAt;
	var font = Font.monospace(12), small = Font.monospace(11);
	var stamp, addFeed, addLog, setCC, label, setItems, refresh, toggle, close;
	var kindColors = (
		prompt: Color(0.15, 0.15, 0.15), thinking: Color.gray(0.45), reading: Color(0.15, 0.4, 0.85),
		searching: Color(0.5, 0.25, 0.75), writing: Color(0.85, 0.45, 0.1), running: Color(0.15, 0.55, 0.25),
		web: Color(0.1, 0.55, 0.6), agent: Color(0.6, 0.2, 0.45), skill: Color(0.6, 0.2, 0.45),
		tool: Color.gray(0.3), failed: Color(0.8, 0.15, 0.15), idle: Color.gray(0.65)
	);

	stamp = { Date.getDate.format("%H:%M:%S  ") };
	addFeed = { |str|
		feedLines.addFirst(stamp.() ++ str);
		if (feedLines.size > 200) { feedLines.pop };
		if (closed.not) { ccFeed.string = feedLines.join("\n") };
	};
	addLog = { |str|
		{
			logLines.addFirst(stamp.() ++ str);
			if (logLines.size > 200) { logLines.pop };
			if (closed.not) { logView.string = logLines.join("\n") };
		}.defer
	};

	// one Claude Code event -> the state line, the prompt box and the feed
	setCC = { |event, kind, detail|
		var shown = kind;
		case
			{ kind == "prompt" } { ccPrompt.string = detail; promptAt = Main.elapsedTime; shown = "thinking"; addFeed.("prompt   " ++ detail) }
			{ kind == "done" } { shown = "thinking" }
			{ kind == "failed" } { addFeed.("failed   " ++ detail); shown = "thinking" }
			{ kind == "idle" } { promptAt = nil; addFeed.("done") }
			{ addFeed.(kind.padRight(9) ++ detail) };
		ccKind = shown;
		ccSince = Main.elapsedTime;
		ccState.string = (if (shown == "idle") { "○ " } { "● " }) ++ shown;
		ccState.stringColor = kindColors[shown.asSymbol] ? Color.gray(0.3);
		ccDetail.string = if (#["thinking", "idle"].includesEqual(shown)) { "" } { detail };
	};

	label = { |playing, name, rest|
		var n = name.asString;
		(if (playing) { "▶ " } { "  " }) ++ n ++ String.fill((18 - n.size).max(1), $ ) ++ rest
	};

	// Qt fires a list's action when code changes its items or value: `updating` makes the
	// actions ignore those, and the selection is put back from `selected`
	setItems = { |view, items, playing, kind, names|
		if (items != view.items) {
			updating = true;
			view.items = items;
			view.colors = playing.collect { |p| if (p) { Color(0.78, 0.93, 0.78) } { Color.white } };
			view.value = if (selected.notNil and: { selected[0] == kind }) { names.indexOf(selected[1]) };
			updating = false;
		}
	};

	refresh = {
		var st, playing;
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
			playing = st[\patterns].count(_[\playing]) + st[\synths].count(_[\playing]);
			header.string = "engine %    server %    CPU %    nodes %    % BPM    playing %%".format(st[\engine],
				if (st[\server]) { "running" } { "NOT RUNNING" }, st[\cpu].asString ++ "%", st[\numSynths],
				st[\tempo].round(0.1), playing, if (ps.server.volume.isMuted) { "    (muted)" } { "" });
			setItems.(patternList, st[\patterns].collect { |p| label.(p[\playing], p[\name], "→ " ++ p[\synth]) },
				st[\patterns].collect(_[\playing]), \pattern, st[\patterns].collect(_[\name]));
			setItems.(synthList, st[\synths].collect { |s| label.(s[\playing], s[\name], s[\kind]) },
				st[\synths].collect(_[\playing]), \synth, st[\synths].collect(_[\name]));
			historyLabel.string = if (ps.historyActive) {
				"playing history: step % of %".format((stepIndex ? 0) + 1, steps.size)
			} { "latest versions" } ++ if (hidden > 0) { "    (% saved-over steps hidden: not stored)".format(hidden) } { "" };
			// a new version (or a watched save) of the selected item: reread its trail
			if (selected.notNil) {
				var entry = st[if (selected[0] == \synth) { \synths } { \patterns }].detect { |e| e[\name] == selected[1] };
				if (entry.notNil and: { entry[\hash] != trailHash }) { showTrail.() };
			};
			ccClock.string = if (promptAt.notNil) {
				var t = (Main.elapsedTime - promptAt).asInteger;
				"working %:%".format(t div: 60, (t % 60).asString.padLeft(2, "0"))
			} { "" };
		}
	};

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

	// the selected item's pairings, read once on selection: only steps whose two versions can both
	// load (saved-over ones were never stored), then a "now" row for the current files.
	// the selected item's pairings, read once on selection: only steps whose two versions can both
	// load (saved-over ones were never stored), then a "now" row for the current files.
	showHistory = {
		var all = if (selected.notNil) { ps.historySteps(selected[0], selected[1]) } { [] };
		if (all.isNil or: { all.notEmpty and: { all[0][\playable].isNil } }) {
			addLog.("history: this engine is older than ui.scd; restart it (tools/start-engine.sh), then reopen the UI");
			all = [];
		};
		steps = all.select(_[\playable]);
		// hiding unstored steps can leave the same versions twice in a row: keep one
		steps = steps.select { |s, i| i == 0 or: { [\pattern, \patternHash, \synthHash].any { |k| steps[i - 1][k] != s[k] } } };
		hidden = all.size - steps.size;
		if (steps.isEmpty or: { steps.last[\current].not }) {
			steps = steps ++ [(now: true, current: true, pattern: all.last !? (_[\pattern]), time: "")];
		};
		steps.do { |s| s[\key] = if (s[\now] == true) { "now" } { [s[\pattern], s[\patternHash], s[\synthHash]].join(":") } };
		// not playing history: what plays is the current files, the last row, so start there and
		// let prev go back in time
		stepIndex = if (ps.historyActive.not) { steps.size - 1 };
		updating = true;
		historyList.items = stepLines.();
		historyList.value = stepIndex;
		updating = false;
	};
	stepLines = {
		steps.collect { |s, i|
			var marks = if (i == stepIndex) { "▶" } { " " };
			if (s[\now] == true) { marks ++ "  now: the current files" } {
				"%  %  % %  on % %%".format(marks, s[\time].drop(5).keep(14).replace("T", " "),
					s[\pattern], s[\patternHash], s[\synth], s[\synthHash], if (s[\current]) { "   (now)" } { "" })
			}
		}
	};

	loadStep = { |i|
		var s = steps[i];
		if (s.notNil) {
			stepIndex = i;
			{
				var res = if (s[\current]) { ps.historyEnd; nil } { ps.historyLoad(s) };
				if (s[\current] and: { s[\pattern].notNil } and: { ps.patternPlaying(s[\pattern]).not }) {
					try { ps.playPattern(s[\pattern]) }
				};
				{
					if (closed.not) {
						updating = true;
						historyList.items = stepLines.();
						historyList.value = i;
						updating = false;
					};
					addLog.(if (res.isNil) { "history: now (the current files)" } {
						"history step %: pattern %, synth %".format(i + 1, res[\pattern], res[\synth]) });
				}.defer;
			}.fork(SystemClock);
		}
	};

	toLatest = {
		{ ps.historyEnd; { if (closed.not) { showHistory.() } }.defer }.fork(SystemClock)
	};

	// with a history step loaded, play / stop is that step's pattern; otherwise the selected item
	toggle = {
		var kind, name, entry;
		if (selected.notNil and: { status.notNil }) {
			#kind, name = selected;
			if (stepIndex.notNil and: { steps[stepIndex] !? (_[\pattern]) !? { |pn| ps.patterns[pn].notNil } ? false }) {
				kind = \pattern; name = steps[stepIndex][\pattern];
			};
			try {
				if (kind == \synth) {
					entry = status[\synths].detect { |s| s[\name] == name };
					if (entry[\playing]) { ps.releaseSynth(name) } { ps.playSynth(name) };
				} {
					entry = status[\patterns].detect { |p| p[\name] == name };
					if (entry[\playing]) { ps.stopPattern(name) } { ps.playPattern(name) };
				};
			} { |err| addLog.("% %: %".format(kind, name, ps.errorText(err))) };
			refresh.();
		};
		nil
	};

	close = {
		if (closed.not) {
			closed = true;
			if (ps.historyActive) { { ps.historyEnd }.fork(SystemClock) };   // don't leave old versions loaded
			poller.stop;
			oscDefs.do(_.free);
			// ui.scd may still be listening on the same subscription
			if (~promptSynthUI.isNil) { NetAddr.localAddr.sendMsg('/ps/unsubscribe') };
			if (~promptSynthUI2.notNil and: { ~promptSynthUI2[\win] === win }) { ~promptSynthUI2 = nil };
		}
	};

	// --- views ---
	win = Window("PromptSynth", Rect(40, 40, 1440, 780));
	header = StaticText().font_(Font.monospace(12, true));
	patternList = ListView().font_(font).selectionMode_(\single);
	synthList = ListView().font_(font).selectionMode_(\single);
	ccState = StaticText().font_(Font.monospace(22, true)).string_("○ idle").stringColor_(kindColors[\idle]);
	ccDetail = StaticText().font_(Font.monospace(13)).string_("");
	ccClock = StaticText().font_(small).align_(\right);
	ccPrompt = StaticText().font_(Font.monospace(12)).string_("(no prompt yet)").minHeight_(48).maxHeight_(80);
	ccFeed = TextView().font_(small).editable_(false);
	trail = TextView().font_(small).editable_(false);
	historyList = ListView().font_(small).selectionMode_(\single)
		.action_({ |v| if (updating.not and: { v.value.notNil } and: { v.value != stepIndex }) { loadStep.(v.value) } });
	historyLabel = StaticText().font_(small).string_("latest versions");
	logView = TextView().font_(small).editable_(false).fixedHeight_(150);

	[[patternList, \pattern], [synthList, \synth]].do { |pair|
		var view = pair[0], kind = pair[1], other = if (kind == \synth) { patternList } { synthList };
		view.action = { |v|
			var names = status !? { status[if (kind == \synth) { \synths } { \patterns }].collect(_[\name]) };
			if (updating.not and: { v.value.notNil } and: { names.notNil } and: { v.value < names.size }) {
				if (selected != [kind, names[v.value]]) {
					selected = [kind, names[v.value]];
					updating = true; other.value = nil; updating = false;
					showTrail.();
					showHistory.();
				};
			};
		};
		view.mouseDownAction = { |v, x, y, mod, button, clicks| if (clicks == 2) { toggle.() }; nil };
	};

	win.layout = VLayout(
		HLayout(header, nil,
			Button().states_([["play / stop"]]).action_({ toggle.() }),
			Button().states_([["mute"], ["unmute"]]).value_(if (ps.server.volume.isMuted) { 1 } { 0 })
				.action_({ |b| if (b.value == 1) { ps.server.volume.mute } { ps.server.volume.unmute } }),
			Button().states_([["panic"]]).action_({ ps.panic })),
		HLayout(
			[VLayout(StaticText().string_("patterns (double-click to start / stop)"), [patternList, stretch: 3],
				StaticText().string_("synths"), [synthList, stretch: 2]), stretch: 2],
			[VLayout(StaticText().string_("trail"), [trail, stretch: 2],
				StaticText().string_("history (click a step to play it)"), [historyList, stretch: 3],
				HLayout(
					Button().states_([["◀ prev"]]).action_({ loadStep.(((stepIndex ? steps.size) - 1).max(0)) }),
					Button().states_([["next ▶"]]).action_({ loadStep.(((stepIndex ? -1) + 1).min(steps.size - 1)) }),
					Button().states_([["latest"]]).action_({ toLatest.() }), nil),
				historyLabel), stretch: 3],
			[VLayout(
				HLayout(StaticText().string_("Claude Code"), nil, ccClock),
				ccState, ccDetail,
				StaticText().string_("prompt"), ccPrompt,
				StaticText().string_("activity"), ccFeed), stretch: 3]),
		StaticText().string_("engine"), logView
	);
	win.onClose = { close.() };
	~promptSynthUI2 = (win: win, close: { win.close });

	// --- Claude Code (hooks) and engine events ---
	oscDefs.add(OSCdef(\ps_ui2_cc, { |msg|
		var event = msg[1].asString, kind = msg[2].asString, detail = (msg[3] ? "").asString;
		{ if (closed.not) { setCC.(event, kind, detail) } }.defer;
	}, '/cc/event').permanent_(true));
	[
		['/ps/event/log', { |m| addLog.(m[1].asString) }],
		['/ps/event/pattern', { |m| addLog.(if (m[2] == 1) { "▶ % on %".format(m[1], m[3]) } { "■ % stopped".format(m[1]) }) }],
		['/ps/event/synth', { |m| addLog.(if (m[2] == 1) { "▶ synth %".format(m[1]) } { "■ synth % released".format(m[1]) }) }],
		['/ps/event/defined', { |m| addLog.("new version: % % %".format(m[1], m[2], m[3])) }],
		['/ps/event/panic', { addLog.("panic: everything stopped") }]
	].do { |pair|
		oscDefs.add(OSCdef(("ps_ui2" ++ pair[0].asString.tr($/, $_)).asSymbol, { |msg| pair[1].(msg) }, pair[0]).permanent_(true));
	};
	NetAddr.localAddr.sendMsg('/ps/subscribe');
	poller = SkipJack({ refresh.() }, 0.25, { closed }, "ps-ui2");

	refresh.();
	win.front;
	addLog.("UI 2 open: listening for Claude Code on port %".format(NetAddr.langPort));
};
)
