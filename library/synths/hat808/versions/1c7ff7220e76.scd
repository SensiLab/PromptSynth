// 808-style hi-hat (one-shot): six square waves at the 808's inharmonic frequencies (times pitch),
// summed, band-passed around `tone` and high-passed twice at `hp` into a metallic hiss, with a
// short exponential decay. decay ~0.05 is a closed hat, 0.3+ opens it.
SynthDef(\hat808, { |out = 0, amp = 0.3, decay = 0.06, tone = 10000, hp = 7000, pitch = 1, pan = 0|
	var osc = Pulse.ar([205.35, 304.41, 369.64, 522.71, 540.54, 812.21] * pitch).sum;
	var env = EnvGen.ar(Env.perc(0.0005, decay, 1, -6), doneAction: 2);
	var sig = BPF.ar(osc, tone.clip(1000, 18000), 0.6);
	sig = HPF.ar(HPF.ar(sig, hp), hp);
	Out.ar(out, Pan2.ar(sig * env, pan, amp));
}, metadata: (specs: (
	decay: [0.01, 1, \exp, 0, 0.06, "s"],
	tone: [2000, 16000, \exp, 0, 10000, "Hz"],
	hp: [2000, 12000, \exp, 0, 7000, "Hz"],
	pitch: [0.5, 2, \exp, 0, 1, "x"],
	pan: [-1, 1]
)))
