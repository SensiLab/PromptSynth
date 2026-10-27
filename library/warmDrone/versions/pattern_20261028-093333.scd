// drifting notes for warmDrone: a random walk over MIDI 50..90 kept in D minor, 4 notes per beat,
// each note at a random place in the stereo field
Pbind(
	\midinote, Pbrown(50, 90, 5).collect { |n| ((n.round - 2).nearestInScale(Scale.minor.degrees) + 2).clip(50, 90) },
	\pan, Pwhite(-0.7, 0.7),
	\dur, 0.25,
	\legato, 1.5
)
