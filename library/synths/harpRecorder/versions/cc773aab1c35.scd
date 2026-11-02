// harpsichord + recorder (sustained). `blend` crossfades them: 0 all harpsichord, 1 all recorder.
// Harpsichord: two plucked strings (Pluck, Karplus-Strong), 8' at the note and 4' an octave up
// (`octave` loud), with the jack's click at the start. The pluck rings over `decay` x 3 and the
// damper stops it at gate off (`release`).
// Recorder: a near-pure tone with weak 2nd and 3rd harmonics, breath noise (`breath`) around the
// pitch, and a chiff at the start: a puff of noise and a brief pitch overshoot. Envelope: attack,
// decay to sustain, release.
// `tone` brightens both: a brighter pluck (less damping in the string) and a harder-blown recorder
// (stronger upper harmonics, more chiff).
// No input in here: map control channels onto params (e.g. mouseX -> blend, mouseY -> tone).
SynthDef(\harpRecorder, { |out = 0, gate = 1, freq = 440, amp = 0.3, attack = 0.03, decay = 0.4,
	sustain = 0.8, release = 0.08, blend = 0.5, tone = 0.5, octave = 0.4, breath = 0.12, pan = 0|
	var env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
	var damper = EnvGen.kr(Env.asr(0.001, 1, release), gate);
	var coef = tone.linlin(0, 1, 0.6, 0.05);
	var exc = WhiteNoise.ar;
	var harp = Pluck.ar(exc, Impulse.ar(0), 0.05, freq.reciprocal, decay * 3, coef)
		+ Pluck.ar(exc, Impulse.ar(0), 0.05, (freq * 2.003).reciprocal, decay * 2, coef, octave);
	var jack = HPF.ar(WhiteNoise.ar, 3000) * EnvGen.ar(Env.perc(0.0005, 0.006)) * 0.3;
	var chiff = EnvGen.kr(Env.perc(0.002, 0.04));
	var f = freq * (1 + (chiff * 0.02 * tone));
	var rec = SinOsc.ar(f) + SinOsc.ar(f * 2, 0, tone.linlin(0, 1, 0.05, 0.3))
		+ SinOsc.ar(f * 3, 0, tone.linlin(0, 1, 0.02, 0.15));
	rec = rec + BPF.ar(WhiteNoise.ar, (freq * 2).clip(100, 16000), 0.6, breath * 3)
		+ (BPF.ar(WhiteNoise.ar, (freq * 4).clip(100, 16000), 0.8) * chiff * tone * 2);
	harp = LeakDC.ar((harp + jack) * damper * 0.6);
	rec = rec * env * 0.35;
	Out.ar(out, Pan2.ar((harp * (1 - blend)) + (rec * blend), pan, amp));
}, metadata: (specs: (
	freq: [30, 4000, \exp, 0, 440, "Hz"],
	attack: [0.001, 1, \exp, 0, 0.03, "s"],
	decay: [0.05, 4, \exp, 0, 0.4, "s"],
	sustain: [0, 1, \lin, 0, 0.8],
	release: [0.01, 2, \exp, 0, 0.08, "s"],
	blend: [0, 1, \lin, 0, 0.5],
	tone: [0, 1, \lin, 0, 0.5],
	octave: [0, 1, \lin, 0, 0.4],
	breath: [0, 1, \lin, 0, 0.12],
	pan: [-1, 1]
)))
