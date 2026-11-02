// dubstep growl bass (sustained). A saw plus an FM sine per voice (`fm` index, modulator at
// `ratio` x the note), through a resonant low-pass that a wobble LFO opens (`wobbleRate` Hz,
// `wobbleDepth`), then a bank of three vowel formants: `vowel` morphs u - o - a - e, and the
// wobble pushes it along by `vowelWob`, so each wobble says "yoi". `formant` mixes the vowels in,
// `drive` saturates it, `sub` adds a clean sine at the note underneath (kept mono).
// Five voices, `detune` semitones across from lowest to highest, each with its own saw, FM sine,
// filter and formants, spread across the stereo field by `spread` (lowest left, highest right).
// Envelope: attack, decay to sustain, release. The wobble starts closed on each note.
// No input in here: map control channels onto params (e.g. mouseX -> vowel, mouseY -> fm).
SynthDef(\growlBass, { |out = 0, gate = 1, freq = 55, amp = 0.3, attack = 0.005, decay = 0.3,
	sustain = 0.8, release = 0.1, cutoff = 300, res = 0.3, wobbleRate = 4, wobbleDepth = 0.8,
	vowel = 0.4, vowelWob = 0.5, formant = 0.6, fm = 1.5, ratio = 2, detune = 0.25, drive = 3,
	sub = 0.6, spread = 1|
	var env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
	var wob = SinOsc.kr(wobbleRate, 1.5pi).range(0, 1) * wobbleDepth;
	// formants (Hz) for u, o, a, e; SelectX crossfades between neighbours
	var v = ((vowel + (wob * vowelWob)).clip(0, 1) * 3);
	var f1 = SelectX.kr(v, [325, 450, 800, 400]), f2 = SelectX.kr(v, [700, 800, 1150, 1600]);
	var f3 = SelectX.kr(v, [2530, 2830, 2900, 2700]);
	var fc = (cutoff * (1 + (wob * 12))).clip(30, 18000);
	var voices = [-1, -0.5, 0, 0.5, 1].collect { |k|
		var fv = freq * (k * detune).midiratio;
		// a random start phase per voice, so the voices (and the channels) differ from the first sample
		var osc = (SawDPW.ar(fv, Rand(-1, 1)) * 0.5)
			+ SinOsc.ar(fv, SinOsc.ar(fv * ratio, Rand(0, 2pi), fm * 2pi) + Rand(0, 2pi), 0.6);
		var filt = RLPF.ar(osc, fc, 1 - (res * 0.9));
		var vox = BPF.ar(filt, f1, 0.12) + BPF.ar(filt, f2, 0.12, 0.7) + BPF.ar(filt, f3, 0.1, 0.4);
		LeakDC.ar((((filt * (1 - formant)) + (vox * formant * 3)) * drive).tanh * 0.5)
	};
	var sig = Splay.ar(voices, spread, 1.3);
	sig = sig + (LPF.ar(SinOsc.ar(freq), 200) * sub ! 2);
	Out.ar(out, sig * env * amp);
}, metadata: (specs: (
	freq: [20, 1000, \exp, 0, 55, "Hz"],
	attack: [0.001, 1, \exp, 0, 0.005, "s"],
	decay: [0.01, 4, \exp, 0, 0.3, "s"],
	sustain: [0, 1, \lin, 0, 0.8],
	release: [0.01, 4, \exp, 0, 0.1, "s"],
	cutoff: [40, 4000, \exp, 0, 300, "Hz"],
	res: [0, 1, \lin, 0, 0.3],
	wobbleRate: [0.25, 32, \exp, 0, 4, "Hz"],
	wobbleDepth: [0, 1, \lin, 0, 0.8],
	vowel: [0, 1, \lin, 0, 0.4],
	vowelWob: [0, 1, \lin, 0, 0.5],
	formant: [0, 1, \lin, 0, 0.6],
	fm: [0, 6, \lin, 0, 1.5],
	ratio: [0.5, 4, \lin, 0, 2],
	detune: [0, 1, \lin, 0, 0.25, "st"],
	drive: [1, 12, \exp, 0, 3],
	sub: [0, 1, \lin, 0, 0.6],
	spread: [0, 1, \lin, 0, 1]
)))
