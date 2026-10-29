// A bass line for moogBass, one 9-beat bar (3 + 3 + 3) looping. A pedal on A1 with octave jumps and
// a G2 pickup, then a climb B1 C#2 D#2 back to A: neighbours from the A whole-tone scale glassSeq
// starts on. It stays on A while glassSeq's root moves.
Pbind(
	\instrument, \moogBass,
	[\midinote, \dur], Pseq([
		[33, 1.5], [45, 0.5], [33, 1],
		[33, 0.75], [45, 0.75], [43, 0.5], [45, 1],
		[35, 1], [37, 1], [39, 0.5], [33, 0.5]
	], inf),
	\legato, 0.85,
	\bar, 9
)
