SynthDef(\perc, { |out = 0, freq = 440, decay = 0.3, amp = 0.3|
	var env = EnvGen.kr(Env.perc(0.001, decay), doneAction: 2);
	Out.ar(out, Pan2.ar(SinOsc.ar(freq) * env * amp));
})
