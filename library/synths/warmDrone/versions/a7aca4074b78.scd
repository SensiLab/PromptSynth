// warm drone pad: 6 drifting detuned VarSaws, breathing low-pass, soft saturation,
// a phase-distorted sub-octave sine (phase pushed by the drone's low band and its own feedback),
// a gentle 4-stage phaser sweeping the low register, and an 'air' layer of hiss and crackle
// that moves between high-passes at airLo and airHi, bypassing the low-pass.
// mouse = 1: MouseX scales the phase distortion (0..2x), MouseY sets the speed of both air
// movements, sweep and shimmer (bottom 1 Hz .. top 1 kHz, log); mouse = 0: params control them
SynthDef(\warmDrone, { |out = 0, gate = 1, freq = 73.42, amp = 0.25, cutoff = 900, res = 0.15,
	detune = 0.12, drift = 0.08, sub = 0.5, width = 0.8, attack = 3, release = 4,
	air = 0.5, airLo = 8000, airHi = 12000, airSweep = 0.04, airRate = 0.15, airDensity = 6,
	phaseMix = 0.35, phaseRate = 0.06, phaseFreq = 180, pdDrive = 1.2, pdFeedback = 0.7, pdMove = 0.4,
	pdRate = 0.1, mouse = 1, keytrack = 1|
	var n = 6;
	var env = EnvGen.kr(Env.asr(attack, 1, release, \sin), gate, doneAction: 2);
	var voices = Array.fill(n, { |i|
		var spread = (i / (n - 1) * 2 - 1) * detune;   // semitones either side
		var f = freq * (spread + LFNoise2.kr(drift * Rand(0.5, 1.5), 0.03)).midiratio;
		VarSaw.ar(f, Rand(0, 1), LFNoise2.kr(drift * Rand(0.5, 1.5)).range(0.3, 0.6))
	});
	var sig = Splay.ar(voices, width) * 0.35;
	// cutoff is set for D2 (73.42 Hz); keytrack 1 moves it an octave per octave of pitch
	var fc = (cutoff * ((freq / 73.42) ** keytrack) * LFNoise2.kr(drift * 0.5).exprange(0.7, 1.4)).clip(40, 18000);
	var hiss = ({ PinkNoise.ar } ! 2) * 0.5 + (Dust.ar(airDensity * [1, 1.13]) * 0.6);
	var airMouse = MouseY.kr(1000, 1, \exponential);
	var sweepRate = Select.kr(mouse, [airSweep, airMouse]);
	var shimmerRate = Select.kr(mouse, [airRate, airMouse]);
	// audio-rate crossfade between two fixed high-passes = a corner moving airLo..airHi at any speed
	var airPos = SinOsc.ar(sweepRate, [0, 0.6pi]).range(0, 1);
	// first-order allpass coefficient for a corner sweeping phaseFreq/2 .. phaseFreq*2
	var pw = tan(pi * SinOsc.kr(phaseRate, [0, 0.5pi]).exprange(phaseFreq * 0.5, phaseFreq * 2) * SampleDur.ir);
	var pc = (pw - 1) / (pw + 1);
	var phased, pdOsc;
	var fb = LocalIn.ar(2);
	var pdAmt = Select.kr(mouse, [1, MouseX.kr(0, 2)]);
	sig = RLPF.ar(sig, fc, 1 - (res * 0.85));
	// phase distortion: low band + slowly breathing self-feedback modulate the sub's phase
	pdOsc = SinOsc.ar(freq * 0.5, [0, 0.5pi] + (LPF.ar(sig, 200) * pdDrive * pdAmt)
		+ (fb * pdFeedback * pdAmt * LFNoise2.ar(pdRate * [1, 1.2]).range(1 - pdMove, 1)));
	LocalOut.ar(pdOsc);
	sig = sig + (pdOsc * sub * 0.4);
	phased = sig;
	4.do { phased = FOS.ar(phased, pc, 1, pc.neg) };
	sig = (sig + (phased * phaseMix)) / (1 + phaseMix);
	sig = (sig * 1.5).tanh * 0.8;
	hiss = (HPF.ar(HPF.ar(hiss, airLo), airLo) * (1 - airPos)) + (HPF.ar(HPF.ar(hiss, airHi), airHi) * airPos);
	hiss = hiss * LFNoise2.ar(shimmerRate * [1, 1.1]).range(0.2, 1);
	sig = sig + (hiss * air);
	sig = LeakDC.ar(sig, 0.9995);   // ~4 Hz, the default (~38 Hz) eats the subs
	Out.ar(out, sig * env * amp);
}, metadata: (specs: (
	freq: [30, 400, \exp, 0, 73.42, "Hz"],
	cutoff: [80, 6000, \exp, 0, 900, "Hz"],
	res: [0, 1],
	detune: [0, 0.5, \lin, 0, 0.12, "st"],
	drift: [0.01, 1, \exp],
	sub: [0, 1],
	width: [0, 1],
	attack: [0.01, 20, \exp, 0, 3, "s"],
	release: [0.01, 20, \exp, 0, 4, "s"],
	air: [0, 1],
	airLo: [4000, 18000, \exp, 0, 8000, "Hz"],
	airHi: [4000, 18000, \exp, 0, 12000, "Hz"],
	airSweep: [0.005, 1000, \exp, 0, 0.04, "Hz"],
	airRate: [0.01, 1000, \exp, 0, 0.15, "Hz"],
	airDensity: [0, 40, \lin, 0, 6, "/s"],
	phaseMix: [0, 1],
	phaseRate: [0.01, 1, \exp, 0, 0.06, "Hz"],
	phaseFreq: [40, 800, \exp, 0, 180, "Hz"],
	pdDrive: [0, 4],
	pdFeedback: [0, 1.5],
	pdMove: [0, 1],
	pdRate: [0.1, 1000, \exp, 0, 0.1, "Hz"],
	mouse: [0, 1, \lin, 1, 1],
	keytrack: [0, 1]
)))
