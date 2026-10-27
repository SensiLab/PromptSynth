// drifting notes for warmDrone: a random walk over MIDI 50..90 kept in D minor, 4 notes per beat
Pbind(
	\midinote, Pbrown(50, 90, 5).collect { |n| ((n.round - 2).nearestInScale(Scale.minor.degrees) + 2).clip(50, 90) },
	\dur, 0.25,
	\legato, 1.5
)
