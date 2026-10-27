SynthDef(\noFree, { |out = 0, gate = 1| Out.ar(out, SinOsc.ar(330 ! 2, 0, 0.05) * EnvGen.kr(Env.asr(0.01, 1, 0.1), gate)) })
