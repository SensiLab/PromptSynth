// fat Minimoog-style lead (sustained): three oscillators like the Model D's, two saws `detune`
// semitones either side of the note and a square an octave below (`sub`), spread across the stereo
// field by `spread`, into a Moog ladder low-pass (MoogFF) at `cutoff` with `res`. A filter envelope
// opens it by `envAmount` and falls back over `fdecay`, so each note has the Moog "pew". Soft drive
// (`drive`) for weight. Envelope: attack, decay to sustain, release.
// No input in here: map control channels onto params.
SynthDef(\fatMoog, { |out = 0, gate = 1, freq = 220, amp = 0.3, attack = 0.005, decay = 0.2,
	sustain = 0.7, release = 0.12, cutoff = 700, res = 1.4, envAmount = 4, fdecay = 0.18,
	detune = 0.15, sub = 0.5, drive = 1.6, spread = 0.7|
	var env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
	var fenv = EnvGen.kr(Env.perc(0.003, fdecay, 1, -4));
	var fc = (cutoff * (1 + (envAmount * fenv))).clip(30, 18000);
	// one voice per oscillator, each through its own ladder filter, spread low to high
	var oscs = [
		SawDPW.ar(freq * detune.neg.midiratio, Rand(-1, 1)),
		Pulse.ar(freq * 0.5, 0.5, sub * 1.4),
		SawDPW.ar(freq * detune.midiratio, Rand(-1, 1))
	];
	var sig = oscs.collect { |o| (MoogFF.ar(o, fc, res) * drive).tanh };
	sig = Splay.ar(sig, spread, 2);
	Out.ar(out, LeakDC.ar(sig) * env * amp);
}, metadata: (specs: (
	freq: [20, 4000, \exp, 0, 220, "Hz"],
	attack: [0.001, 2, \exp, 0, 0.005, "s"],
	decay: [0.01, 4, \exp, 0, 0.2, "s"],
	sustain: [0, 1, \lin, 0, 0.7],
	release: [0.01, 4, \exp, 0, 0.12, "s"],
	cutoff: [40, 8000, \exp, 0, 700, "Hz"],
	res: [0, 3.5, \lin, 0, 1.4],
	envAmount: [0, 10, \lin, 0, 4],
	fdecay: [0.01, 2, \exp, 0, 0.18, "s"],
	detune: [0, 0.6, \lin, 0, 0.15, "st"],
	sub: [0, 1, \lin, 0, 0.5],
	drive: [1, 8, \exp, 0, 1.6],
	spread: [0, 1, \lin, 0, 0.7]
), map: (cutoff: [\mouseX, 150, 4000, \exp], res: [\mouseY, 0, 3.2, \lin])))
