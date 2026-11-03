// Arpeggios of the "Never Gonna Give You Up" chorus chords, IV - V - iii - vi in A flat major
// (D flat, E flat, C minor, F minor), two beats each, as 16ths: up through the chord over two
// octaves and back down a little. One pass is 8 beats, the \bar.
var chords = [[49, 53, 56], [51, 55, 58], [48, 51, 55], [53, 56, 60]];   // Db3 F3 Ab3, Eb3 G3 Bb3, C3 Eb3 G3, F3 Ab3 C4
var shape = [0, 1, 2, 3, 4, 5, 4, 2];   // indexes into the chord over two octaves
var notes = chords.collect { |c| var two = c ++ (c + 12); shape.collect { |i| two[i] } }.flat;
Pbind(
	\instrument, \fatMoog,
	\midinote, Pseq(notes, inf),
	\dur, 0.25,
	\legato, 0.7,
	\amp, 0.3,
	\bar, 8
)
