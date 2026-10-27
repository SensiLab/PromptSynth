SynthDef(\silent, { |out = 0, gate = 1, amp = 0| Out.ar(out, SinOsc.ar(440 ! 2) * amp * EnvGen.kr(Env.asr, gate, doneAction: 2)) })
