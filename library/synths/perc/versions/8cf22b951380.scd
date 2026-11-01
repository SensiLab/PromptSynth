SynthDef(\perc, { |out = 0, freq = 440, attack = 0.001, decay = 0.3, amp = 0.3|
	var env = EnvGen.kr(Env.perc(attack, decay), doneAction: 2);
	Out.ar(out, Pan2.ar(SinOsc.ar(freq) * env * amp));
}, metadata: (specs: (
	attack: [0.0005, 1, \exp, 0, 0.001, "s"],
	decay: [0.01, 4, \exp, 0, 0.3, "s"]
)))
