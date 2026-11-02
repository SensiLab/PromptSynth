// Analysis views on what you hear (the hardware outs, after the master limiter), using the
// AnalysisViews classes (Projects/AnalysisViews, installed into Extensions by its install.scd).
// Opens two windows: a stack of a scrolling mel spectrogram, live mel bands and MFCCs, and a
// stereo field / phase view. `tools/start-engine.sh --views` opens them at boot; otherwise
// evaluate this file once the engine is up. Evaluating it again replaces the open views. After
// Cmd-period, evaluate it again.
//
// The views put their analysis synths in the server's default group, which normally runs before
// the engine's groups, so they would read bus 0 before the master writes it and see silence.
// This moves the default group to after the engine's master group.
(
var ps = ~promptSynth;
~promptSynthViews !? { |old| old[\close].value };
if (ps.isNil or: { ps.isReady != true }) {
	"[ps-views] the engine isn't ready: evaluate engine/main.scd first".postln;
} {
	if (\ScrollSpectrogram.asClass.isNil) {
		"[ps-views] AnalysisViews isn't installed: run Projects/AnalysisViews/install.scd".postln;
	} {
		var server = ps.server, w, w2, p1, p2, p3, a, m, f, p, closed = false, close;

		server.defaultGroup.moveAfter(ps.masterGroup);

		close = {
			if (closed.not) {
				closed = true;
				[a, m, f, p].do { |v| v !? { try { v.stop } } };
				[w, w2].do { |win| if (win.notNil and: { win.isClosed.not }) { win.close } };
				if (~promptSynthViews.notNil and: { ~promptSynthViews[\win] === w }) { ~promptSynthViews = nil };
			}
		};

		// the spectrogram and the bands ask for the same mel analysis, so they share one feed
		w = Window("PromptSynth analysis", Rect(100, 60, 900, 880)).front;
		p1 = CompositeView(w, Rect(0, 0, 900, 400)).resize_(5);
		p2 = CompositeView(w, Rect(0, 405, 900, 220)).resize_(5);
		p3 = CompositeView(w, Rect(0, 630, 900, 240)).resize_(5);
		a = ScrollSpectrogram(p1, source: \mel, numBands: 96, bufSize: 2048, numRows: 360,
			seconds: 10, fps: 30, map: \viridis, dbFloor: -95, dbCeil: -10, minFreq: 30,
			maxFreq: 18000, inBus: 0, server: server);
		m = MelBandsView(p2, numBands: 96, minFreq: 30, maxFreq: 18000, bufSize: 2048,
			map: \viridis, dbFloor: -95, dbCeil: -10, fps: 45, inBus: 0, server: server);
		f = MFCCView(p3, numCoeffs: 13, startCoeff: 1, map: \coolwarm, mode: \bars,
			seconds: 10, fps: 30, inBus: 0, server: server);

		w2 = Window("PromptSynth stereo", Rect(1010, 60, 520, 560)).front;
		p = StereoPhaseView(CompositeView(w2, w2.view.bounds).resize_(5), numBands: 16,
			minFreq: 40, maxFreq: 16000, inBus: 0, mode: \position, map: \viridis,
			dbFloor: -60, dbCeil: 0, fps: 30, integration: 0.3, server: server);

		[a, m, f, p].do(_.start);
		w.onClose = { close.() };
		w2.onClose = { close.() };
		~promptSynthViews = (win: w, close: close, spectrogram: a, bands: m, mfcc: f, stereo: p);
		"[ps-views] open: spectrogram, bands, MFCC, stereo".postln;
	};
};
)
