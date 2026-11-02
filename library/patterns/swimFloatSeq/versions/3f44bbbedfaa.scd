// swimFloat on one constant pitch (A2), in 8ths, 16ths and 32nds (0.5, 0.25, 0.125 beats). Each
// 4-beat bar gets a fresh rhythm, and a density that random-walks between sparse (mostly 8ths)
// and dense (mostly 32nds), so it keeps drifting and never settles into a loop. The timbre
// params walk too (Pbrown: bounded random walks), each at its own small step. rich and rate are
// left to the mouse.
Pbind(
	\instrument, \swimFloat,
	\midinote, 45,
	\dur, Prout({
		var dens = 0.4;
		loop {
			var t = 0, w;
			dens = (dens + 0.15.rand2).fold(0, 1);
			w = [1 - dens, 0.6, dens].normalizeSum;
			while { t < 4 } { var d = [0.5, 0.25, 0.125].wchoose(w).min(4 - t); t = t + d; d.yield };
		}
	}),
	\legato, Pbrown(0.5, 1.5, 0.05),
	\attack, Pbrown(0.01, 0.3, 0.02),
	\release, Pbrown(0.3, 2.5, 0.1),
	\bright, Pbrown(0.1, 0.7, 0.03),
	\warmth, Pbrown(0.6, 0.95, 0.01),
	\width, Pbrown(0.3, 1, 0.05),
	\swirl, Pbrown(0, 1, 0.04),
	\detune, Pbrown(0.02, 0.2, 0.01),
	\drive, Pbrown(1, 3, 0.05),
	\amp, 0.18,
	\bar, 4
)
