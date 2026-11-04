// The next part of Axel F (from memory, check by ear): the chord section, eight bars in F minor,
// Db | Eb | Cm | Fm twice, as syncopated stabs (on 1, the "a" of 1, 2-and, 3-and, 4) on warmLead.
(
var chords = [[1, 5, 8], [3, 7, 10], [0, 3, 7], [0, 5, 8]];   // Db, Eb, Cm, Fm (close voicings)
var rhythm = [0.75, 0.75, 1, 0.5, 1];                           // one bar of stabs
Pbind(
	\instrument, \warmLead,
	\note, Pseq(chords.collect { |c| c ! rhythm.size }.flatten(1), inf),
	\dur, Pseq(rhythm, inf),
	\octave, 5,
	\legato, Pseq([0.6, 0.6, 0.5, 0.8, 0.9], inf),
	\amp, Pseq([0.3, 0.22, 0.24, 0.22, 0.26], inf),
	\bar, 4
)
)
