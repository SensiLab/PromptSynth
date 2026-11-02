// Australian magpie, one call per note (one-shot). The synth plays the whole carol: a 6-syllable
// phrase, each syllable gliding between two pitches (semitones from the note), with gaps between.
// `freq` transposes the call, `register` lifts it into magpie range (4 = 2 octaves up), `speed`
// stretches it (1 = about 1.5 s), and `vary` nudges every pitch and length by a different random
// amount on each note, so no two calls are the same.
// Two voices, like the two sides of a bird's syrinx: the second sits `voiceInterval` semitones
// above (7 = a fifth; under 1 they beat into a gurgle), `twoVoice` loud, with its own warble.
// Warble: pitch wobble (`warbleDepth` semitones at `warbleRate` Hz) and level flutter
// (`warbleAm`), with `warbleJitter` drifting rate and depth so it isn't a clean LFO. Fluty
// harmonics (`harm`) and breath noise (`breath`).
// Envelope: each syllable rises over `attack` and falls over `decay`.
// Space: `pan` uses the time difference between the ears (up to 0.6 ms) as well as level;
// `distance` (0..1) makes it quieter, duller (air absorbs highs) and more reflected; `flight`
// drifts the pan during the call, so the bird moves while it sings.
// No input in here: map control channels onto params.
SynthDef(\magpie, { |out = 0, freq = 440, amp = 0.3, attack = 0.012, decay = 0.04, register = 4,
	speed = 1, vary = 0.3, warbleRate = 25, warbleDepth = 0.6, warbleAm = 0.4, warbleJitter = 0.3,
	twoVoice = 0.5, voiceInterval = 7, harm = 0.25, breath = 0.08, pan = 0, distance = 0.2, flight = 0.2|
	// syllables: [start pitch, end pitch, length, gap after], at speed 1
	var syl = [[0, 3, 0.18, 0.06], [7, 5, 0.12, 0.05], [12, 10, 0.22, 0.08],
		[5, 9, 0.15, 0.04], [3, -2, 0.25, 0.06], [0, 0, 0.3, 0]];
	var amps = [0.8, 1, 0.9, 0.85, 1, 0.7];
	var plevels = [], ptimes = [], alevels = [0], atimes = [], total = 0;
	var f = freq * register, pitch, env, voice, sig, dry, refl, p, gain;
	syl.do { |s, i|
		var len = s[2] * (1 + Rand(vary.neg, vary) * 0.5) / speed, gap = s[3] / speed;
		var a = attack.min(len * 0.4), d = decay.min(len * 0.5);
		plevels = plevels ++ [s[0] + Rand(vary.neg, vary), s[1] + Rand(vary.neg, vary)];
		ptimes = ptimes ++ [len, gap.max(0.001)];
		alevels = alevels ++ [amps[i], amps[i], 0, 0];
		atimes = atimes ++ [a, (len - a - d).max(0.001), d, gap.max(0.001)];
		total = total + len + gap;
	};
	pitch = EnvGen.kr(Env(plevels, ptimes.drop(-1), \sin));
	// 0.15 s of silence at the end lets the reflections ring out before the synth frees
	env = EnvGen.kr(Env(alevels ++ [0], atimes ++ [0.15], \sin), doneAction: 2);
	voice = { |offset, rateMul|
		var rate = warbleRate * rateMul * LFNoise2.kr(4).range(1 - warbleJitter, 1 + warbleJitter);
		var w = SinOsc.kr(rate, Rand(0, 2pi));
		var depth = warbleDepth * LFNoise2.kr(3).range(1 - warbleJitter, 1);
		var pf = (f * (pitch + offset + (w * depth)).midiratio).clip(60, 16000);
		var tone = SinOsc.ar(pf) + SinOsc.ar(pf * 2, 0, harm) + SinOsc.ar(pf * 3, 0, harm * 0.35);
		tone * (1 - (warbleAm * (w * 0.5 + 0.5)))
	};
	sig = voice.(0, 1) + (voice.(voiceInterval, Rand(0.85, 1.15)) * twoVoice);
	sig = sig + BPF.ar(WhiteNoise.ar, (f * pitch.midiratio).clip(200, 12000), 0.4, breath * 4);
	sig = LPF.ar(sig * env * 0.9, distance.linexp(0, 1, 18000, 2500));
	// space: level + ear-delay panning, drifting with flight; reflections grow with distance
	p = (pan + Line.kr(0, Rand(-1, 1) * flight, total)).clip(-1, 1);
	dry = Pan2.ar(sig, p * 0.7);
	dry = [DelayC.ar(dry[0], 0.001, p.max(0) * 0.0006), DelayC.ar(dry[1], 0.001, p.neg.max(0) * 0.0006)];
	refl = LPF.ar(sig, 5000);
	refl = [DelayN.ar(refl, 0.05, 0.013) + DelayN.ar(refl, 0.05, 0.031, 0.6),
		DelayN.ar(refl, 0.05, 0.017) + DelayN.ar(refl, 0.05, 0.037, 0.6)];
	gain = 1 / (1 + (distance * 3));
	Out.ar(out, ((dry * (1 - (distance * 0.5))) + (refl * distance * 0.5)) * gain * amp);
}, metadata: (specs: (
	freq: [30, 4000, \exp, 0, 440, "Hz"],
	attack: [0.001, 0.1, \exp, 0, 0.012, "s"],
	decay: [0.005, 0.2, \exp, 0, 0.04, "s"],
	register: [1, 8, \exp, 0, 4, "x"],
	speed: [0.25, 4, \exp, 0, 1, "x"],
	vary: [0, 1, \lin, 0, 0.3],
	warbleRate: [2, 80, \exp, 0, 25, "Hz"],
	warbleDepth: [0, 3, \lin, 0, 0.6, "st"],
	warbleAm: [0, 1, \lin, 0, 0.4],
	warbleJitter: [0, 0.9, \lin, 0, 0.3],
	twoVoice: [0, 1, \lin, 0, 0.5],
	voiceInterval: [-12, 12, \lin, 0, 7, "st"],
	harm: [0, 1, \lin, 0, 0.25],
	breath: [0, 1, \lin, 0, 0.08],
	pan: [-1, 1],
	distance: [0, 1, \lin, 0, 0.2],
	flight: [0, 1, \lin, 0, 0.2]
)))
