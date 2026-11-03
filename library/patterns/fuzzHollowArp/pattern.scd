// Arpeggios under fuzzHollowSeq's Clair de lune melody, bars 1-32. The chords are the score's
// own: on each dotted quarter (three per 9/8 bar), every note sounding in both hands, folded into
// G3-F5 from the bass up. Same source as the melody (Mutopia Project MIDI, public domain).
// Each chord plays as three 8ths, bass, middle, top; where the score sounds fewer than three notes
// the previous chord carries on. A small attack and a long release let the notes ring into each
// other. Same \stretch and \bar as fuzzHollowSeq, so the two line up when started together.
var bars = [
	[\rest, [65, 68], [65, 68, 73]],   // 1 - | FAb | FAbDb
	[[66, 69, 73, 77], [66, 69, 72, 75], [66, 69, 72, 75]],   // 2 GbADbF | GbACEb | GbACEb
	[[65, 68, 72, 75], [65, 68, 70, 73], [65, 68, 70]],   // 3 FAbCEb | FAbBbDb | FAbBb
	[[63, 66, 70, 73], [63, 66, 68, 72], [63, 66, 68, 72]],   // 4 EbGbBbDb | EbGbAbC | EbGbAbC
	[[61, 63, 66, 72], [61, 63, 66, 70], [60, 63, 66, 68]],   // 5 DbEbGbC | DbEbGbBb | CEbGbAb
	[[58, 61, 63, 68], [58, 61, 63, 66], [57, 60, 63, 65]],   // 6 BbDbEbAb | BbDbEbGb | ACEbF
	[[56, 58, 61, 65], [56, 58, 61, 65], [66, 70, 73, 75]],   // 7 AbBbDbF | AbBbDbF | GbBbDbEb
	[[65, 68, 70, 75], [65, 68, 70, 73], [63, 66, 68, 72]],   // 8 FAbBbEb | FAbBbDb | EbGbAbC
	[[61, 68], [65, 68], [65, 68, 73]],   // 9 DbAb | FAb | FAbDb
	[[66, 73, 77], [66, 70, 73, 75], [61, 63, 66, 70]],   // 10 GbDbF | GbBbDbEb | DbEbGbBb
	[[65, 73, 75], [65, 68, 73], [56, 61, 65]],   // 11 FDbEb | FAbDb | AbDbF
	[[66, 73, 77], [66, 70, 73, 75], [61, 66, 70]],   // 12 GbDbF | GbBbDbEb | DbGbBb
	[[56, 61], [56, 58, 59, 61, 65], [56, 59, 61, 65]],   // 13 AbDb | AbBbBDbF | AbBDbF
	[[58, 65], [58, 63, 65], [65, 70, 73]],   // 14 BbF | BbEbF | FBbDb
	[[63], [63, 65, 66, 70], [63, 66, 70]],   // 15 Eb | EbFGbBb | EbGbBb
	[[61, 66, 70], [60, 66, 70], [58, 61, 66]],   // 16 DbGbBb | CGbBb | BbDbGb
	[[63, 70], [63, 65, 66, 70], [63, 66, 70]],   // 17 EbBb | EbFGbBb | EbGbBb
	[[61, 66, 70], [60, 66, 70], [58, 63, 66]],   // 18 DbGbBb | CGbBb | BbEbGb
	[[56, 58, 66], [56, 60, 63], [58, 63, 66]],   // 19 AbBbGb | AbCEb | BbEbGb
	[[57], [57, 60, 63, 66], [66, 72, 75]],   // 20 A | ACEbGb | GbCEb
	[[58], [58, 61, 68], [58, 61, 66]],   // 21 Bb | BbDbAb | BbDbGb
	[[56], [56, 58, 63, 66], [66, 70, 75]],   // 22 Ab | AbBbEbGb | GbBbEb
	[[61], [61, 68, 70], [61, 66, 70]],   // 23 Db | DbAbBb | DbGbBb
	[[63], [63, 66, 70, 73], [58, 61, 66]],   // 24 Eb | EbGbBbDb | BbDbGb
	[[65, 68, 73], [65, 68, 73], [64, 68, 70, 73]],   // 25 FAbDb | FAbDb | EAbBbDb
	[[63, 66, 68, 73], [63, 66, 68, 73], [56, 60, 63, 66]],   // 26 EbGbAbDb | EbGbAbDb | AbCEbGb
	[[61, 65, 68], [65, 68], [56, 59]],   // 27 DbFAb | FAb | AbB
	[[61, 65, 68], [65, 68], [56, 59]],   // 28 DbFAb | FAb | AbB
	[[61, 65], [65, 73], [56, 61, 65]],   // 29 DbF | FDb | AbDbF
	[[63, 67], [55, 58, 61], [63, 73]],   // 30 EbG | GBbDb | EbDb
	[[56, 58], [66, 70], [65, 72]],   // 31 AbBb | GbBb | FC
	[[56, 58], [66, 70], [65, 72]],   // 32 AbBb | GbBb | FC
];
var notes = List[], last = [56, 61, 65];
bars.flatten(1).do { |c|
	if (c == \rest) { 3.do { notes.add(\rest) } } {
		if (c.size < 3) { c = (c ++ last).asSet.asArray.sort } { last = c };
		notes.addAll([c[0], c[c.size div: 2], c.last]);
	}
};
Pbind(
	\instrument, \fuzzHollow,
	\midinote, Pseq(notes, inf),
	\dur, 0.5,
	\stretch, 2,
	\legato, 0.4,
	\attack, 0.005,
	\release, 2.5,
	\amp, 0.3,
	\bar, 9
)
