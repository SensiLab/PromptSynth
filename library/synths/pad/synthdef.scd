SynthDef(\pad, { |out = 0, gate = 1, freq = 220, cutoff = 1200, amp = 0.2, detune = 0.01,
	attack = 0.1, decay = 0.3, sustain = 1, release = 0.5|
	var env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
	var sig = RLPF.ar(Saw.ar(freq * [1, 1 + detune]), cutoff, 0.3);
	Out.ar(out, LeakDC.ar(sig) * env * amp);
}, metadata: (specs: (cutoff: [100, 8000, \exp], detune: [0, 0.05],
	attack: [0.001, 4, \exp, 0, 0.1, "s"], decay: [0.01, 4, \exp, 0, 0.3, "s"],
	sustain: [0, 1, \lin, 0, 1], release: [0.01, 8, \exp, 0, 0.5, "s"])))
