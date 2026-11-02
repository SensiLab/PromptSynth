// A magpie in the garden: the synth sings each carol, this decides the bird's behaviour.
// Bouts over two 8-beat bars (a call is ~3 beats at 120 BPM): two calls and a pause, then one
// call and a longer pause. Calls start on a few home notes (D, F, G, A; magpie range comes from
// the synth's register). Each call lands somewhere new around you, at a new distance, a little
// louder or softer, and varied by a different amount.
Pbind(
	\instrument, \magpie,
	// [\midinote, \dur], Pseq([
	// 	[62, 3], [67, 3], [\rest, 2],
	// 	[65, 4], [\rest, 4]
	// ], inf),
	\midinote, 62,
	\dur, 2,
	\pan, Pwhite(-0.8, 0.8),
	\distance, Pwhite(0.05, 0.6),
	\vary, 0.1,//Pwhite(0.15, 0.5),
	\amp, 0.0,//Pwhite(0.22, 0.32),
	\bar, 8
)
