// warm drone pad: 6 drifting detuned VarSaws, breathing low-pass, sub-octave sine, soft saturation,
// plus an 'air' layer of hiss and crackle above airFreq that bypasses the low-pass
SynthDef(\warmDrone, { |out = 0, gate = 1, freq = 73.42, amp = 0.25, cutoff = 900, res = 0.15,
	detune = 0.12, drift = 0.08, sub = 0.5, width = 0.8, attack = 3, release = 4,
	air = 0.5, airFreq = 12000, airRate = 0.15, airDensity = 6|
	var n = 6;
	var env = EnvGen.kr(Env.asr(attack, 1, release, \sin), gate, doneAction: 2);
	var voices = Array.fill(n, { |i|
		var spread = (i / (n - 1) * 2 - 1) * detune;   // semitones either side
		var f = freq * (spread + LFNoise2.kr(drift * Rand(0.5, 1.5), 0.03)).midiratio;
		VarSaw.ar(f, Rand(0, 1), LFNoise2.kr(drift * Rand(0.5, 1.5)).range(0.3, 0.6))
	});
	var sig = Splay.ar(voices, width) * 0.35;
	var fc = (cutoff * LFNoise2.kr(drift * 0.5).exprange(0.7, 1.4)).clip(40, 18000);
	var hiss = ({ PinkNoise.ar } ! 2) * 0.5 + (Dust.ar(airDensity * [1, 1.13]) * 0.6);
	sig = RLPF.ar(sig, fc, 1 - (res * 0.85));
	sig = sig + (SinOsc.ar(freq * 0.5, [0, 0.5pi]) * sub * 0.4);
	sig = (sig * 1.5).tanh * 0.8;
	hiss = HPF.ar(HPF.ar(hiss, airFreq), airFreq) * LFNoise2.kr(airRate * [1, 1.1]).range(0.2, 1);
	sig = sig + (hiss * air);
	sig = LeakDC.ar(sig);
	Out.ar(out, sig * env * amp);
}, metadata: (specs: (
	freq: [30, 400, \exp, 0, 73.42, "Hz"],
	cutoff: [80, 6000, \exp, 0, 900, "Hz"],
	res: [0, 1],
	detune: [0, 0.5, \lin, 0, 0.12, "st"],
	drift: [0.01, 1, \exp],
	sub: [0, 1],
	width: [0, 1],
	attack: [0.01, 20, \exp, 0, 3, "s"],
	release: [0.01, 20, \exp, 0, 4, "s"],
	air: [0, 1],
	airFreq: [6000, 18000, \exp, 0, 12000, "Hz"],
	airRate: [0.01, 2, \exp],
	airDensity: [0, 40, \lin, 0, 6, "/s"]
)))
