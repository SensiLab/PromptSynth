// A two-bar break on fmSweep: kick, snare and hat are all the FM synth, set per voice
// (pitch, short envelopes, FM ratio, sub, tinkle). 16ths; a step's number is its level,
// 0 is a rest. timbre and sweep stay on the mouse, so it shapes the kit too.
(
var steps = { |levels| Pseq(levels.collect { |a| if (a == 0) { Rest(0) } { a } }, inf) };
var kick = Pbind(\instrument, \fmSweep, \dur, 0.25,
	\amp, steps.([
		1, 0, 0.9, 0,  0, 0, 0, 0,  0, 0, 0.9, 0.8,  0, 0, 0, 0,
		1, 0, 0.9, 0,  0, 0, 0, 0,  0, 0, 0.9, 0,    0, 0, 0, 0]) * 0.5,
	\note, 0, \octave, 3, \ratio, 1, \envAmt, 1, \sub, 2, \subPd, 0.6, \warmth, 1, \tinkle, 0,
	\attack, 0.001, \decay, 0.22, \release, 0.1, \legato, 0.5);
var snare = Pbind(\instrument, \fmSweep, \dur, 0.25,
	\amp, steps.([
		0, 0, 0, 0,  1, 0, 0, 0.3,  0, 0.35, 0, 0,  1, 0, 0, 0.3,
		0, 0, 0, 0,  1, 0, 0, 0.3,  0, 0.35, 0, 0,  0, 0.4, 1, 0]) * 0.32,
	\note, 7, \octave, 4, \ratio, 2.37, \detune, 1, \envAmt, 1, \sub, 0.2, \subPd, 1, \warmth, 0.2,
	\tinkle, 0.7, \attack, 0.001, \decay, 0.13, \release, 0.06, \legato, 0.4);
var hat = Pbind(\instrument, \fmSweep, \dur, 0.25,
	\amp, steps.([
		1, 0, 0.6, 0.3,  1, 0, 0.6, 0,  1, 0, 0.6, 0.3,  1, 0, 0.6, 0,
		1, 0, 0.6, 0.3,  1, 0, 0.6, 0,  1, 0.3, 0.6, 0,  1, 0, 0.6, 0.4]) * 0.12,
	\note, 7, \octave, 5, \ratio, 2.73, \detune, Pwhite(1,100), \envAmt, 1, \sub, 0, \warmth, 0, \tinkle, 2,
	\attack, Pwhite(0.001,0.005), \decay, 0.04, \release, Pwhite(0.1,0.4), \legato, 0.2);
Ppar([kick, snare, hat])
)
