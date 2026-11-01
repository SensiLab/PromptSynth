// Bach, Well-Tempered Clavier book 1, prelude no. 1 in C (BWV 846), bars 1-19, looping: the
// broken-chord figure as one line, no held notes. Each bar is five notes played
// low, low, high three, high three, twice. 16ths are 0.5 beats here (a quarter = 60 at 120 BPM),
// so one bar of the prelude is the 8-beat \bar.
var bars = [
	[60, 64, 67, 72, 76], [60, 62, 69, 74, 77], [59, 62, 67, 74, 77], [60, 64, 67, 72, 76],
	[60, 64, 69, 76, 81], [60, 62, 66, 69, 74], [59, 62, 67, 74, 79], [59, 60, 64, 67, 72],
	[57, 60, 64, 67, 72], [50, 57, 62, 66, 72], [55, 59, 62, 67, 71], [55, 58, 64, 67, 73],
	[53, 57, 62, 69, 74], [53, 56, 62, 65, 71], [52, 55, 60, 67, 72], [52, 53, 57, 60, 65],
	[50, 53, 57, 60, 65], [43, 50, 55, 59, 65], [48, 52, 55, 60, 64]
];
var notes = bars.collect { |c| (c ++ c.drop(2)).dup(2) }.flat;
Pbind(
	\instrument, \hollowLog,
	\midinote, Pseq(notes, inf),
	\dur, 0.5,
	\amp, 0.25,
	\bar, 8
)
