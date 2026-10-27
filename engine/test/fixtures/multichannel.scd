SynthDef(\multi, { |out = 0, gate = 1| Out.ar(out, SinOsc.ar([100, 200, 300, 400], 0, 0.05) * EnvGen.kr(Env.asr, gate, doneAction: 2)) })
