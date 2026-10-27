SynthDef(\pad, { |out = 0, gate = 1, freq = 220, cutoff = 1200, amp = 0.2|
	var env = EnvGen.kr(Env.asr(0.1, 1, 0.5), gate, doneAction: 2);
	var sig = RLPF.ar(Saw.ar(freq * [1, 1.005]), cutoff, 0.3);
	Out.ar(out, LeakDC.ar(sig) * env * amp);
}, metadata: (specs: (cutoff: [100, 8000, \exp])))
