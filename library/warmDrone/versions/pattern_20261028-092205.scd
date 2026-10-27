// slow drifting notes for warmDrone: a random walk over MIDI 30..54 kept in D minor,
// 6-12 s per note (in seconds whatever the tempo), overlapping so notes crossfade
Pbind(
	\midinote, Pbrown(30, 54, 5).collect { |n| ((n.round - 2).nearestInScale(Scale.minor.degrees) + 2).clip(30, 54) },
	\dur, Pwhite(6.0, 12.0) * Pfunc { TempoClock.default.tempo },
	\legato, 1.5
)
