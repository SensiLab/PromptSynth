// D minor 7 arpeggio (D F A C) over 3 octaves from D3, up and back down, 4 notes per beat.
// The root moves through [0, 3, 6, 9, 6, 3] semitones, changing every 3 loops of the arpeggio.
// Every tonic is doubled 2 octaves lower. Each note sits at a random place in the stereo field.
// A bar is one pass of the arpeggio (24 sixteenths = 6 beats): play, stop and swaps land there.
var arp = ([50, 53, 57, 60] +.x [0, 12, 24] ++ [86]).sort.mirror1;
Pbind(
	\midinote, Pseq([0, 3, 6, 9, 6, 3].collect { |root|
		Pseq(arp + root, 3).collect { |n| if ((n - root - 50) % 12 == 0) { [n, n - 24] } { n } }
	}, inf),
	\pan, Pwhite(-0.7, 0.7),
	\dur, 0.25,
	\legato, 1.5,
	\bar, 6
)
