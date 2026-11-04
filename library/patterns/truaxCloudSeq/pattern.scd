// In the style of Barry Truax (Riverrun, Arras): long overlapping cloud sections, each a tendency
// mask gliding over its length (centre, spread, density, grain length), going from sparse high
// droplets, through denser and lower FM streams, down to a low drone, then narrowing into a tone
// that opens out again. A sparse layer of high glints drifts over it.
(
var glide = Pkey(\dur) * Pkey(\legato) / Pfunc { TempoClock.default.tempo };
// [note, bend, bw, bwEnd, density, densityEnd, gdur, gdurEnd, index]
var sections = [
	[35, -2, 0.3, 0.8, 4, 12, 0.03, 0.05, 0],      // high droplets
	[26, -5, 0.8, 1.5, 12, 40, 0.05, 0.08, 0.5],   // thickening
	[14, -12, 1.5, 2.5, 40, 120, 0.08, 0.03, 1.5], // dense stream, falling
	[-5, -10, 2.5, 0.5, 120, 60, 0.03, 0.15, 3],   // low, FM-rich
	[-15, 24, 0.5, 0.05, 60, 200, 0.15, 0.2, 0.5], // narrows into a rising tone
	[9, 33, 0.05, 2, 200, 15, 0.2, 0.02, 2]        // opens out and thins away
];
var cloud = Pbind(
	\instrument, \grainCloud,
	[\note, \bend, \bw, \bwEnd, \density, \densityEnd, \gdur, \gdurEnd, \index], Pseq(sections, inf),
	\dur, 24, \legato, 1.35,
	\glide, glide,
	\attack, 5, \release, 6, \amp, 0.35, \ratio, Pseq([1, 1, 1.5, 2.01, 1, 3.03], inf)
);
var glints = Pbind(
	\instrument, \grainCloud,
	\dur, Pwrand([1, 2, 3, 4], [0.2, 0.3, 0.3, 0.2], inf),
	\note, Pwhite(36, 48) + Prand([Rest(0), 0, 0], inf),
	\bend, Pwhite(-3, 3), \bw, 0.15, \bwEnd, 0.4, \density, 6, \densityEnd, 2,
	\gdur, 0.015, \gdurEnd, 0.04, \index, Pwhite(0, 1.0), \legato, 1,
	\glide, glide, \attack, 0.05, \release, 1.5, \amp, 0.12
);
Ppar([cloud, glints])
)
