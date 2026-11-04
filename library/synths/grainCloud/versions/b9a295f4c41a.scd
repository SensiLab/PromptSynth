// Granular sine/FM cloud, after Barry Truax: asynchronous grains (Dust) whose frequency, spread,
// density and grain length glide from a start value to an end value over `glide` seconds, like a
// tendency mask. freq = centre; bend = semitones the centre moves; bw = spread in octaves around it;
// density = grains per second; gdur = grain length; index = FM per grain (0 = pure sine grains,
// higher = Truax's FM grains). The level follows the overlap so thin and dense clouds sit together.
SynthDef(\grainCloud, { |out = 0, gate = 1, freq = 440, amp = 0.2, pan = 0,
	attack = 2, decay = 1, sustain = 0.8, release = 3,
	bend = 0, bw = 0.5, bwEnd = 0.5, density = 20, densityEnd = 20, gdur = 0.05, gdurEnd = 0.05,
	glide = 8, ratio = 1, index = 0, spread = 0.8|
	var env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
	var centre = freq * Line.kr(0, bend, glide).midiratio;
	var spreadOct = Line.kr(bw, bwEnd, glide);
	var dens = XLine.kr(density.max(0.5), densityEnd.max(0.5), glide);
	var dur = XLine.kr(gdur.max(0.002), gdurEnd.max(0.002), glide);
	var trig = Dust.ar(dens);
	var gfreq = (centre * (2 ** (TRand.ar(-0.5, 0.5, trig) * spreadOct))).clip(30, 16000);
	var sig = GrainFM.ar(2, trig, dur, gfreq, gfreq * ratio, index * TRand.ar(0.4, 1, trig),
		(TRand.ar(-1, 1, trig) * spread + pan).clip(-1, 1), -1, 1024);
	var gain = (dens * dur).max(1).sqrt.reciprocal;
	Out.ar(out, LeakDC.ar(sig) * gain * env * amp);
}, metadata: (specs: (
	bend: [-36, 36], bw: [0, 4], bwEnd: [0, 4], density: [0.5, 400, \exp], densityEnd: [0.5, 400, \exp],
	gdur: [0.002, 0.5, \exp], gdurEnd: [0.002, 0.5, \exp], glide: [0.1, 60, \exp], ratio: [0.25, 8, \exp],
	index: [0, 10], spread: [0, 1]
)))
