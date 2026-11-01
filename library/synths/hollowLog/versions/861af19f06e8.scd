// hollow log struck like a piano string (one-shot). The string is 8 slightly stretched partials
// (piano inharmonicity), each a pair of sines a hair apart so they beat like unison strings, with
// a piano's two-stage decay: a quick drop after the strike, then a long tail over `decay`. Higher
// partials die sooner. The log is a few inharmonic wood modes (Ringz) on the same strike, `knock`
// loud, `hollow` spreading them apart. Vibrato (vibDepth semitones) fades in after vibDelay, so
// it's only heard in the tail. Then a low-pass at `cutoff` and a high-pass at `hp`, and a tight
// delay (`spread` seconds) on the right channel for L/R separation.
// Pad layer: three detuned saws per note, softened by a low-pass at padTone, swelling in over
// padAttack and fading over padRelease, `pad` loud. It goes through the same filters and delay.
// No input in here: map control channels onto params (e.g. mouseX -> cutoff, mouseY -> hp).
SynthDef(\hollowLog, { |out = 0, freq = 220, amp = 0.3, decay = 4, knock = 0.5, hollow = 1,
	vibDepth = 0.12, vibRate = 5, vibDelay = 1.2, cutoff = 4000, hp = 60, spread = 0.012,
	pad = 0.3, padAttack = 0.4, padRelease = 2.5, padTone = 1200, padDetune = 0.1|
	var n = 8, strike, str, log, padSig, sig;
	var vib = SinOsc.kr(vibRate, Rand(0, 2pi), vibDepth
		* EnvGen.kr(Env([0, 0, 1], [vibDelay, 1.5], [0, 2]))).midiratio;
	var life = Line.kr(0, 0, (decay * 1.1 + 0.01).max(0.7).max(padAttack + padRelease), doneAction: 2);   // longest layer
	strike = EnvGen.ar(Env.perc(0.0005, 0.015)) * (WhiteNoise.ar(0.4) + 1);
	str = Array.fill(n, { |i|
		var k = i + 1, pf = freq * k * (1 + (0.0004 * k * k)).sqrt;
		var env = EnvGen.kr(Env([0, 1, 0.3, 0], [0.003, decay * 0.1 / k, decay / (1 + (k * 0.4))], [0, -5, -4]));
		SinOsc.ar(pf * vib * [1, 1.0008], Rand(0, 2pi)).sum * env / k
	}).sum * 0.35;
	log = Ringz.ar(strike * 0.05, freq * [1, 1 + (1.32 * hollow), 1 + (3.25 * hollow), 1 + (5.63 * hollow)],
		[0.5, 0.25, 0.12, 0.07], [1, 0.6, 0.35, 0.2]).sum * knock;
	padSig = LPF.ar(Saw.ar(freq * vib * [padDetune.neg, 0, padDetune].midiratio).sum * 0.2, padTone.clip(100, 12000))
		* EnvGen.kr(Env([0, 1, 0], [padAttack, padRelease], [2, -3])) * pad;
	sig = LPF.ar(str + log + padSig, cutoff.clip(80, 18000));
	sig = HPF.ar(sig, hp.clip(20, 4000));
	Out.ar(out, life + [sig, DelayN.ar(sig, 0.05, spread.clip(0, 0.05))] * amp);
}, metadata: (specs: (
	freq: [30, 4000, \exp, 0, 220, "Hz"],
	decay: [0.2, 12, \exp, 0, 4, "s"],
	knock: [0, 2, \lin, 0, 0.5],
	hollow: [0.3, 2, \lin, 0, 1],
	vibDepth: [0, 1, \lin, 0, 0.12, "st"],
	vibRate: [0.5, 10, \exp, 0, 5, "Hz"],
	vibDelay: [0, 4, \lin, 0, 1.2, "s"],
	cutoff: [100, 16000, \exp, 0, 4000, "Hz"],
	hp: [20, 2000, \exp, 0, 60, "Hz"],
	spread: [0, 0.04, \lin, 0, 0.012, "s"],
	pad: [0, 1, \lin, 0, 0.3],
	padAttack: [0.01, 3, \exp, 0, 0.4, "s"],
	padRelease: [0.1, 8, \exp, 0, 2.5, "s"],
	padTone: [200, 8000, \exp, 0, 1200, "Hz"],
	padDetune: [0, 0.5, \lin, 0, 0.1, "st"]
)))
