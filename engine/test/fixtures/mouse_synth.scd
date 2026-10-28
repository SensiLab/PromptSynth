SynthDef(\mouseSynth, { |out = 0, gate = 1| Out.ar(out, SinOsc.ar(MouseX.kr(200, 800) ! 2, 0, 0.1) * EnvGen.kr(Env.asr, gate, doneAction: 2)) })
