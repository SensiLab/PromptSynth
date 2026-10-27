SynthDef(\nan, { |out = 0| Out.ar(out, (Line.ar(0, 0, 1).reciprocal ! 2) * EnvGen.kr(Env.perc(0.01, 0.5), doneAction: 2)) })
