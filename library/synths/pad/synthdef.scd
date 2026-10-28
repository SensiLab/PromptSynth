SynthDef(\pad, { |out = 0, gate = 1, freq = 220, cutoff = 1200, amp = 0.2, detune = 0.01|
	var env = EnvGen.kr(Env.asr(0.1, 1, 0.5), gate, doneAction: 2);
	var sig = RLPF.ar(Saw.ar(freq * [1, 1 + detune]), cutoff, 0.3);
	Out.ar(out, LeakDC.ar(sig) * env * amp);
}, metadata: (specs: (cutoff: [100, 8000, \exp], detune: [0, 0.05])))
