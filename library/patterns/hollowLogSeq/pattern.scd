// Bach, Well-Tempered Clavier book 1, prelude no. 1 in C (BWV 846), bars 1-19, looping: the
// broken-chord figure as one line, no held notes. Each bar is five notes played
// low, low, high three, high three, twice. 16ths are 0.5 beats here (a quarter = 60 at 120 BPM),
// so one bar of the prelude is the 8-beat \bar.
var bars = [
	[60 - 24, 64, 67, 72, 76], [60- 24, 62, 69, 74, 77], [59- 24, 62, 67, 74, 77], [60- 24, 64, 67, 72, 76],
	[60 -24, 64, 69, 76, 81], [60- 24, 62, 66, 69, 74], [59- 24, 62, 67, 74, 79], [59- 24, 60, 64, 67, 72],
	[57 - 24, 60, 64, 67, 72], [50- 24, 57, 62, 66, 72], [55- 24, 59, 62, 67, 71], [55- 24, 58, 64, 67, 73],
	[53 - 24, 57, 62, 69, 74], [53- 24, 56, 62, 65, 71], [52- 24, 55, 60, 67, 72], [52- 24, 53, 57, 60, 65],
	[50 - 24, 53, 57, 60, 65], [43- 24, 50, 55, 59, 65], [48- 24, 52, 55, 60, 64]
];
// spread across 3 octaves: every note but the bass goes as written, up one or down one octave in
// turn (a 3-step cycle against the 8-note figure, so each figure lands differently)
var notes = bars.collect { |c| (c ++ c.drop(2)).dup(2) }.flat
	.collect { |n, i| if (i % 8 == 0) { n } { n + [0, 12, -12].wrapAt(i) } };
Pbind(
	\instrument, \hollowLog,
	\midinote, Pseq(notes, inf),
	\dur, 0.25,
	\amp, 0.25,
	\bar, 8,
	\vibDepth, 10.9,
	\pad, 1,
	\padWarm, 1,
	\padRelease,0.6,
	\padAttack, 0.02,
	\padDetune, 0.05,
)
