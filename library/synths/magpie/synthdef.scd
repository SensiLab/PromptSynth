// Australian magpie, one call per note (one-shot), built on what's known about how magpies sing
// (Suthers, Wild & Kaplan 2011, J Comp Physiol A 197:45-59; Walsh et al. 2023, J R Soc Interface).
//
// The syrinx has two sound sources, one per side, each opened or closed by its own valve. A
// syllable can use the low side, the high side, or both. In two-voice syllables the left (high)
// side sits `voiceInterval` semitones above the right (low) side.
//
// The warble is not an LFO. Magpie amplitude modulation comes from frequencies interacting:
// - linearly: a close partner tone `beat` Hz away beats against each voice, `beatMix` loud
//   (the AM rate is the frequency difference)
// - nonlinearly: the voices are driven through a saturator (`couple`), which adds sum and
//   difference tones (sidebands), more so when two voices sound
// `jitter` lets air-sac pressure drift the beat and the pitch. `fmRate` / `fmDepth` add a
// frequency wobble on top, for syllables that trill.
// Pulse tones ("vocal fry"): a pulse train at `pulseRate` Hz ringing the voice's pitch, for the
// rasp in some syllables. Which syllables, and how much, is in the table; `pulse` scales it.
// Pressure: louder where a syllable climbs, as raising air pressure raises pitch and level together.
// Warble syllables are near-pure tones (1-2.5 kHz), so `harm` is low.
//
// Syllable table: [start pitch, end pitch, length, gap after, sides (0 low, 1 high, 2 both),
// pulse]. Gaps inside a call are short (~8 ms, under 25 ms). Any number of rows. `freq` transposes
// the call, `register` lifts it into magpie range, `speed` stretches it, `vary` nudges every
// pitch and length differently on each note.
// Envelope: each syllable rises over `attack` and falls over `decay` (both shortened to fit it).
// Space: `pan` with the time difference between the ears (to 0.6 ms) as well as level;
// `distance` quieter, duller and more reflected; `flight` drifts pan during the call.
// No input in here: map control channels onto params.
SynthDef(\magpie, { |out = 0, freq = 440, amp = 0.3, attack = 0.006, decay = 0.02, register = 3,
	speed = 1, vary = 0.3, voiceInterval = 12, twoVoice = 0.7, beat = 30, beatMix = 0.6, couple = 0.4,
	jitter = 0.3, fmRate = 18, fmDepth = 0.3, pulse = 1, pulseRate = 180, pressure = 0.4,
	harm = 0.08, breath = 0.04, pan = 0, distance = 0.2, flight = 0.2|
	// [start, end, length, gap, sides, pulse], at speed 1
	var syl = [
		[0, 4, 0.16, 0.012, 2, 0],      // rising, both sides
		[9, 2, 0.09, 0.008, 1, 0],      // down sweep, high side
		[12, 12, 0.2, 0.02, 2, 0],      // long high, both
		[5, 0, 0.07, 0.008, 0, 0.7],    // noisy line: pulse tone, low side
		[10, 3, 0.1, 0.01, 1, 0],       // down sweep
		[3, 7, 0.06, 0.008, 1, 0],      // short high
		[7, -3, 0.25, 0, 2, 0.2]        // closing down sweep, both, a little rough
	];
	// var syl = [[0, 3, 0.28, 0.46],[5, 2, 0.28, 0.46]];
	var plevels = [], ptimes = [], lo = [0], hi = [0], pl = [0], atimes = [], total = 0;
	var f = freq * register, pitch, envLo, envHi, envPulse, done, side, sig, dry, refl, p, gain;
	syl.do { |s|
		var len = s[2] * (1 + Rand(vary.neg, vary) * 0.5) / speed, gap = (s[3] / speed).max(0.002);
		var a = attack.min(len * 0.4), d = decay.min(len * 0.5);
		var l = if (s[4] != 1) { 1 } { 0 }, h = if (s[4] != 0) { 1 } { 0 };
		plevels = plevels ++ [s[0] + Rand(vary.neg, vary), s[1] + Rand(vary.neg, vary)];
		ptimes = ptimes ++ [len, gap];
		lo = lo ++ [l, l, 0, 0];
		hi = hi ++ [h, h, 0, 0];
		pl = pl ++ [s[5], s[5], 0, 0];
		atimes = atimes ++ [a, (len - a - d).max(0.001), d, gap];
		total = total + len + gap;
	};
	pitch = EnvGen.kr(Env(plevels, ptimes.drop(-1), \sin));
	envLo = EnvGen.kr(Env(lo, atimes, \sin));
	envHi = EnvGen.kr(Env(hi, atimes, \sin));
	envPulse = EnvGen.kr(Env(pl, atimes, \sin)) * pulse;
	// frees the synth once the call and its reflections are done
	done = Line.kr(0, 0, total + 0.15, doneAction: 2);
	// one side of the syrinx: a near-pure tone, its beating partner, and its pulse tone
	side = { |offset, env|
		var drift = LFNoise2.kr(5).range(1 - jitter, 1 + jitter);
		var press = 1 + (pressure * Slope.kr(pitch).clip(-60, 60) / 60);
		var pf = (f * (pitch + offset + (SinOsc.kr(fmRate * Rand(0.9, 1.1), Rand(0, 2pi)) * fmDepth)
			+ LFNoise1.kr(8, jitter * 0.3)).midiratio).clip(60, 12000);
		var tone = SinOsc.ar(pf) + SinOsc.ar(pf + (beat * drift), Rand(0, 2pi), beatMix)
			+ SinOsc.ar(pf * 2, 0, harm);
		var rasp = Ringz.ar(Impulse.ar(pulseRate * drift), pf, 0.004) * 0.08;
		((tone * (1 - envPulse.min(1))) + (rasp * envPulse)) * env * press.max(0.2)
	};
	sig = side.(0, envLo) + (side.(voiceInterval, envHi) * twoVoice);
	// nonlinear interaction between the sources: sidebands, the gurgle when both sides sound
	sig = ((sig * (1 + (couple * 4))).tanh / (1 + (couple * 2))) * 1.5;
	sig = sig + BPF.ar(WhiteNoise.ar, (f * pitch.midiratio).clip(200, 12000), 0.4, breath * 4 * (envLo + envHi).min(1));
	sig = LPF.ar(sig + (done * 0), distance.linexp(0, 1, 18000, 2500));
	// space: level + ear-delay panning, drifting with flight; reflections grow with distance
	p = (pan + Line.kr(0, Rand(-1, 1) * flight, total)).clip(-1, 1);
	dry = Pan2.ar(sig, p * 0.7);
	dry = [DelayC.ar(dry[0], 0.001, p.max(0) * 0.0006), DelayC.ar(dry[1], 0.001, p.neg.max(0) * 0.0006)];
	refl = LPF.ar(sig, 5000);
	refl = [DelayN.ar(refl, 0.05, 0.013) + DelayN.ar(refl, 0.05, 0.031, 0.6),
		DelayN.ar(refl, 0.05, 0.017) + DelayN.ar(refl, 0.05, 0.037, 0.6)];
	gain = 1 / (1 + (distance * 3));
	Out.ar(out, ((dry * (1 - (distance * 0.5))) + (refl * distance * 0.5)) * gain * amp);
}, metadata: (specs: (
	freq: [30, 4000, \exp, 0, 440, "Hz"],
	attack: [0.001, 0.1, \exp, 0, 0.006, "s"],
	decay: [0.002, 0.5, \exp, 0, 0.02, "s"],
	register: [1, 8, \exp, 0, 3, "x"],
	speed: [0.25, 4, \exp, 0, 1, "x"],
	vary: [0, 1, \lin, 0, 0.3],
	voiceInterval: [-12, 24, \lin, 0, 12, "st"],
	twoVoice: [0, 1, \lin, 0, 0.7],
	beat: [0, 120, \lin, 0, 30, "Hz"],
	beatMix: [0, 1, \lin, 0, 0.6],
	couple: [0, 1, \lin, 0, 0.4],
	jitter: [0, 0.9, \lin, 0, 0.3],
	fmRate: [1, 60, \exp, 0, 18, "Hz"],
	fmDepth: [0, 4, \lin, 0, 0.3, "st"],
	pulse: [0, 2, \lin, 0, 1],
	pulseRate: [40, 800, \exp, 0, 180, "Hz"],
	pressure: [0, 1, \lin, 0, 0.4],
	harm: [0, 1, \lin, 0, 0.08],
	breath: [0, 1, \lin, 0, 0.04],
	pan: [-1, 1],
	distance: [0, 1, \lin, 0, 0.2],
	flight: [0, 1, \lin, 0, 0.2]
)))
