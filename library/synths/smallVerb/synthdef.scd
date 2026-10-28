// small room reverb insert for the whole mix: placed at the end of the source group,
// reads the mix from `in` and writes dry + wet back. Wet is high-passed so the subs stay dry and tight.
SynthDef(\smallVerb, { |out = 0, in = 0, gate = 1, mix = 0.18, room = 0.35, damp = 0.55,
	predelay = 0.012, lowCut = 250|
	var dry = In.ar(in, 2);
	var env = EnvGen.kr(Env.asr(0.5, 1, 2), gate, doneAction: 2);
	var wet = DelayN.ar(dry, 0.1, predelay);
	wet = FreeVerb2.ar(wet[0], wet[1], 1, room, damp);
	wet = HPF.ar(wet, lowCut);
	ReplaceOut.ar(out, dry + (wet * mix * env));
}, metadata: (fx: true, specs: (
	mix: [0, 1],
	room: [0, 1],
	damp: [0, 1],
	predelay: [0, 0.1, \lin, 0, 0.012, "s"],
	lowCut: [20, 2000, \exp, 0, 250, "Hz"]
)))
