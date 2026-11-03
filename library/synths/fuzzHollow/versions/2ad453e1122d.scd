// fuzzy, warm, hollow (sustained). Three voices `detune` semitones apart, spread across the stereo
// field (`spread`). Each voice is a pulse wave: `hollow` 1 is a square (odd harmonics only, the
// hollow clarinet-like sound), 0 a thin narrow pulse; a slow LFO moves the width (`pwmRate`,
// `pwmDepth`) so it breathes. `fuzz` drives it into soft clipping with a little hiss on top,
// a sine at the note keeps the body (`body`), and a warm low-pass at `cutoff` wobbles with a slow
// LFO (`lfoRate`, `lfoDepth`). Each voice's LFOs start at their own phase, so the voices drift.
// Envelope: attack, decay to sustain, release.
// No input in here: map control channels onto params (e.g. mouseX -> hollow, mouseY -> fuzz).
SynthDef(\fuzzHollow, { |out = 0, gate = 1, freq = 220, amp = 0.3, attack = 0.08, decay = 0.3,
	sustain = 0.8, release = 0.5, hollow = 0.7, fuzz = 0.4, cutoff = 1800, res = 0.2, body = 0.3,
	lfoRate = 0.3, lfoDepth = 0.3, pwmRate = 0.2, pwmDepth = 0.1, detune = 0.12, spread = 0.8|
	var env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
	var voices = [-1, 0, 1].collect { |k|
		var fv = freq * (k * detune).midiratio;
		var width = (0.5 - ((1 - hollow) * 0.4) + SinOsc.kr(pwmRate * Rand(0.8, 1.2), Rand(0, 2pi), pwmDepth)).clip(0.05, 0.95);
		var osc = Pulse.ar(fv, width);
		var fz = ((osc * (1 + (fuzz * 8))).tanh / (1 + (fuzz * 2))) + (HPF.ar(PinkNoise.ar, 2000) * fuzz * 0.06);
		var fc = (cutoff * (1 + (SinOsc.kr(lfoRate * Rand(0.8, 1.2), Rand(0, 2pi)) * lfoDepth))).clip(60, 16000);
		RLPF.ar(fz, fc, 1 - (res * 0.8)) + SinOsc.ar(fv, Rand(0, 2pi), body)
	};
	var sig = Splay.ar(voices, spread, 0.9);
	Out.ar(out, LeakDC.ar(sig) * env * amp);
}, metadata: (specs: (
	freq: [30, 4000, \exp, 0, 220, "Hz"],
	attack: [0.001, 4, \exp, 0, 0.08, "s"],
	decay: [0.01, 4, \exp, 0, 0.3, "s"],
	sustain: [0, 1, \lin, 0, 0.8],
	release: [0.01, 6, \exp, 0, 0.5, "s"],
	hollow: [0, 1, \lin, 0, 0.7],
	fuzz: [0, 1, \lin, 0, 0.4],
	cutoff: [100, 10000, \exp, 0, 1800, "Hz"],
	res: [0, 1, \lin, 0, 0.2],
	body: [0, 1, \lin, 0, 0.3],
	lfoRate: [0.02, 8, \exp, 0, 0.3, "Hz"],
	lfoDepth: [0, 0.9, \lin, 0, 0.3],
	pwmRate: [0.02, 8, \exp, 0, 0.2, "Hz"],
	pwmDepth: [0, 0.4, \lin, 0, 0.1],
	detune: [0, 0.6, \lin, 0, 0.12, "st"],
	spread: [0, 1, \lin, 0, 0.8]
)))
