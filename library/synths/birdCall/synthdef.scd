// bird call (one-shot): a whistle `register` times above the note (default 2 octaves up) that
// chirps up `chirp` semitones into the note over the first part of the call and droops `droop`
// semitones as it fades, with a fast trill (`trillRate` Hz) wobbling pitch (`trillDepth`
// semitones) and level (`trillAm`). A touch of 2nd harmonic and band-passed breath noise around
// the whistle. Envelope: rises over `attack`, falls over `decay`. Each call lands at a random spot
// `panSpread` either side of `pan`, like birds around you.
// No input in here: map control channels onto params.
SynthDef(\birdCall, { |out = 0, freq = 440, amp = 0.3, attack = 0.03, decay = 0.25, register = 4,
	chirp = 2, droop = 3, trillRate = 28, trillDepth = 0.8, trillAm = 0.5, harm = 0.15, breath = 0.1,
	pan = 0, panSpread = 0.5|
	var f = (freq * register).clip(200, 12000);
	var env = EnvGen.kr(Env.perc(attack, decay, 1, -4), doneAction: 2);
	var sweep = EnvGen.kr(Env([chirp.neg, 0, droop.neg], [attack + (decay * 0.25), decay * 0.75], [-3, 2]));
	var trill = SinOsc.kr(trillRate * Rand(0.9, 1.1), Rand(0, 2pi));
	var pitch = f * (sweep + (trill * trillDepth)).midiratio;
	var sig = SinOsc.ar(pitch) + SinOsc.ar(pitch * 2, 0, harm)
		+ BPF.ar(WhiteNoise.ar, pitch.clip(200, 16000), 0.2, breath * 3);
	sig = sig * (1 - (trillAm * (trill * 0.5 + 0.5)));
	Out.ar(out, Pan2.ar(sig * env * 0.5, (pan + Rand(panSpread.neg, panSpread)).clip(-1, 1), amp));
}, metadata: (specs: (
	freq: [30, 4000, \exp, 0, 440, "Hz"],
	attack: [0.001, 0.5, \exp, 0, 0.03, "s"],
	decay: [0.02, 2, \exp, 0, 0.25, "s"],
	register: [1, 8, \exp, 0, 4, "x"],
	chirp: [-24, 24, \lin, 0, 12, "st"],
	droop: [-12, 12, \lin, 0, 3, "st"],
	trillRate: [1, 60, \exp, 0, 28, "Hz"],
	trillDepth: [0, 4, \lin, 0, 0.8, "st"],
	trillAm: [0, 1],
	harm: [0, 1, \lin, 0, 0.15],
	breath: [0, 1, \lin, 0, 0.1],
	pan: [-1, 1],
	panSpread: [0, 1, \lin, 0, 0.5]
)))
