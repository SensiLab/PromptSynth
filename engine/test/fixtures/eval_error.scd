SynthDef(\evalError, { |out = 0| Out.ar(out, SinOsc.ar(440).noSuchMethod) })
