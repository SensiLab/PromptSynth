// mono-synth bass: two saws detuned either side of the note plus a square an octave below (sub),
// through a Moog ladder low-pass (MoogFF) with resonance, gently saturated. The filter envelope
// opens the cutoff by envAmount and falls back to it over `decay`; the amp envelope decays to
// `sustain` over the same `decay`, so one param sets how plucky or long the note is.
// A small vibrato (vibDepth semitones at vibRate) runs all the time.
// No input in here: map control channels onto params (e.g. mouseX -> cutoff, mouseY -> decay).
SynthDef(\moogBass, { |out = 0, gate = 1, freq = 55, amp = 0.3, cutoff = 400, res = 1.8,
	envAmount = 3, attack = 0.005, decay = 0.4, sustain = 0.5, release = 0.15, detune = 0.08,
	sub = 0.5, vibDepth = 0.08, vibRate = 5.5, pan = 0|
	var f = freq * SinOsc.kr(vibRate, Rand(0, 2pi), vibDepth).midiratio;
	var aenv = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
	var fenv = EnvGen.kr(Env.adsr(attack, decay, 0, release), gate);
	var osc = (Saw.ar(f * [detune.neg, detune].midiratio).sum * 0.5) + (Pulse.ar(f * 0.5) * sub);
	var sig = MoogFF.ar(osc, (cutoff * (1 + (envAmount * fenv))).clip(30, 18000), res);
	sig = (sig * 1.5).tanh;
	Out.ar(out, Pan2.ar(sig, pan, amp * aenv));
}, metadata: (specs: (
	freq: [20, 1000, \exp, 0, 55, "Hz"],
	cutoff: [40, 8000, \exp, 0, 400, "Hz"],
	res: [0, 3.5, \lin, 0, 1.8],
	envAmount: [0, 8, \lin, 0, 3],
	attack: [0.001, 1, \exp, 0, 0.005, "s"],
	decay: [0.02, 3, \exp, 0, 0.4, "s"],
	sustain: [0, 1],
	release: [0.01, 3, \exp, 0, 0.15, "s"],
	detune: [0, 0.5, \lin, 0, 0.08, "st"],
	sub: [0, 1],
	vibDepth: [0, 1, \lin, 0, 0.08, "st"],
	vibRate: [0.5, 12, \exp, 0, 5.5, "Hz"],
	pan: [-1, 1]
)))
