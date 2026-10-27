SynthDef(\fixedBus, { |out = 0| Out.ar(0, SinOsc.ar(440, 0, 0.1) ! 2) })
