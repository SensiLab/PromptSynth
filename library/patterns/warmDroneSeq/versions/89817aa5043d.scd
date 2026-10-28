// drifting notes for warmDrone: a random walk over MIDI 30..54 kept in D minor, one note per beat
Pbind(
	\midinote, Pbrown(30, 54, 5).collect { |n| ((n.round - 2).nearestInScale(Scale.minor.degrees) + 2).clip(30, 54) },
	\dur, 1,
	\legato, 1.5
)
