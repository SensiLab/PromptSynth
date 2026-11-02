// Progressive house, deadmau5 style, for growlBass: an 8-bar loop in F minor, i - VI - III - VII
// (F, Db, Ab, Eb, two bars each), as an offbeat bass: a note on every "and", jumping an octave
// on the third. It evolves slowly rather than changing: the filter builds over 16 bars and falls
// back over the next 16, and every 8 bars the wobble changes speed (1, 2, 4, 2 per beat), locked
// to the tempo. vowel and fm are left to the mouse.
var roots = [41, 41, 37, 37, 44, 44, 39, 39];   // F2 F2 Db2 Db2 Ab2 Ab2 Eb2 Eb2, one per bar
// var bar = { |r| [\rest, r, \rest, r, \rest, r + 12, \rest, r] };
var bar = { |r| [r] };

Pbind(
	\instrument, \growlBass,
	\note, Pseq(roots.collect(bar).flat.stutter(4), inf) - 60,   // \note is midinote - 60 at the default \octave 5
	\octave, Pseq([5, 6], inf),
	\dur, 0.5,
	\cutoff, Pseg(Pseq([150, 1500], inf), 64, \exp, inf),
	\wobbleRate, Pstep(Pseq([1, 2, 4, 2], inf), 32) * Pfunc { thisThread.clock.tempo },
	\amp, 0.35,
	\bar, 4
)
