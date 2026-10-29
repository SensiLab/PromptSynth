// glass with a whisper attack: five sine partials at glass-bowl ratios, each a pair of sines
// `shimmer` Hz apart (times the partial number) so they beat slowly like real glass. Upper partials
// settle lower and sooner (ring), bright tilts the balance towards them. The whisper is soft
// band-passed breath noise that swells over the first half of the attack and is gone by about
// 2 x attack, while the glass blooms in late under it (slow-start curve): air first, then glass.
SynthDef(\glass, { |out = 0, gate = 1, freq = 440, amp = 0.2, attack = 0.25, release = 2.5,
	ring = 3, bright = 0.6, shimmer = 0.4, whisper = 0.5, whisperFreq = 4000, whisperWidth = 0.6,
	width = 0.6, pan = 0|
	var ratios = [1, 2.32, 4.25, 6.63, 9.38];
	var env = EnvGen.kr(Env.asr(attack, 1, release, [4, -4]), gate, doneAction: 2);
	var partials = ratios.collect { |r, i|
		var f = (freq * r).clip(20, 18000), ph = Rand(0, 2pi);
		var level = (bright ** i) * EnvGen.kr(Env([0, 1, 0.6 ** i], [attack, ring / (i + 1)], [4, -3]));
		(SinOsc.ar(f, ph) + SinOsc.ar(f + (shimmer * (i + 1)), ph)) * level
	};
	var breath = EnvGen.kr(Env([0, 1, 0], [attack * 0.5, attack * 1.5], [2, -4]));
	var air = BPF.ar(PinkNoise.ar([1, 1]), whisperFreq.clip(200, 16000) * [1, 1.07], whisperWidth) * 1.5;
	var sig = Splay.ar(partials, width, 1, pan) * 0.25 * env;
	Out.ar(out, (sig + (Balance2.ar(air[0], air[1], pan) * whisper * breath)) * amp);
}, metadata: (specs: (
	freq: [30, 4000, \exp, 0, 440, "Hz"],
	attack: [0.01, 4, \exp, 0, 0.25, "s"],
	release: [0.05, 10, \exp, 0, 2.5, "s"],
	ring: [0.2, 10, \exp, 0, 3, "s"],
	bright: [0, 1],
	shimmer: [0, 4, \lin, 0, 0.4, "Hz"],
	whisper: [0, 1],
	whisperFreq: [500, 12000, \exp, 0, 4000, "Hz"],
	whisperWidth: [0.1, 2, \exp, 0, 0.6],
	width: [0, 1],
	pan: [-1, 1]
)))
