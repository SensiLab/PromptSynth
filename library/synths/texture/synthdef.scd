// texture: three slowly beating sines on `note` (a hair sharp, and just over an octave up),
// spread across the stereo field by `width`. Envelope: attack, decay to sustain, release at gate off.
SynthDef(\texture, { |out = 0, gate = 1, note = 42, width = 0.5,
	attack = 0.05, decay = 0.3, sustain = 1, release = 1|
	var env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
	var sig = Splay.ar(SinOsc.ar(note.midicps * [1, 1.004, 2.01]) * 0.1, width);
	Out.ar(out, sig * env);
}, metadata: (specs: (
	note: [24, 96, \lin, 0, 42],
	width: [0, 1],
	attack: [0.001, 8, \exp, 0, 0.05, "s"],
	decay: [0.01, 4, \exp, 0, 0.3, "s"],
	sustain: [0, 1, \lin, 0, 1],
	release: [0.01, 8, \exp, 0, 1, "s"]
)))
