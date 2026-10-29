// 16th-note 808 hats over a 9-beat bar (3 + 3 + 3, like moogBassSeq), accents through amp:
// the first 16th of each 3-beat group is the strong accent, every off-beat 8th a medium one,
// the rest ghost notes, and the bar's last 16th a pickup accent into the next bar.
var beat = [0.14, 0.07, 0.3, 0.09];
var amps = 9.collect { |b| beat.copy.put(0, if (b % 3 == 0) { 0.55 } { 0.14 }) }.flat.put(35, 0.4);
Pbind(
	\instrument, \hat808,
	\dur, 0.25,
	\amp, Pseq(amps, inf),
	\bar, 9
)
