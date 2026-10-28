// D major 7 arpeggio (D F# A C#) over 3 octaves from D3, up and back down, 4 notes per beat,
// each note at a random place in the stereo field
Pbind(
	\midinote, Pseq(([50, 54, 57, 61] +.x [0, 12, 24] ++ [86]).sort.mirror1, inf),
	\pan, Pwhite(-0.7, 0.7),
	\dur, 0.25,
	\legato, 1.5
)
