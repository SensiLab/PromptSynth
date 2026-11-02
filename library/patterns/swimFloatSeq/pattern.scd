// swimFloat on one constant pitch (A2), in 8ths, 16ths and 32nds (0.5, 0.25, 0.125 beats). Each
// 4-beat bar gets a fresh rhythm, and a density that random-walks between sparse (mostly 8ths)
// and dense (mostly 32nds), so it keeps drifting and never settles into a loop. The timbre
// params walk too (Pbrown: bounded random walks), each at its own small step. rich and rate are
// left to the mouse.
Pbind(
	\instrument, \swimFloat,
	\note, Pseq([0,7,10,12,15,19], inf),
	\octave, 3,
	\root, Pseq([0,3,-2].stutter(24), inf),
	\dur, 0.25,
	\legato, Pbrown(0.5, 1.5, 0.05),
	\attack, 0.003,
	\release, 0.1,//Pbrown(0.3, 2.5, 0.1),
	\bright, Pbrown(0.1, 0.7, 0.03),
	\warmth, Pbrown(0.6, 0.95, 0.01),
	\width, Pbrown(0.3, 1, 0.05),
	\swirl, 0.1,//Pbrown(0, 1, 0.04),
	\detune, 0.1,//Pbrown(0.02, 0.2, 0.01),
	\drive, Pbrown(1, 3, 0.05),
	\transPitch, Pwhite(0, 19),
	\transTime, Pexprand(0.002, 0.03),
	\fuzz, Pwhite(0.05, 0.1),
	\amp, 0.18,
	\bar, 4
)
