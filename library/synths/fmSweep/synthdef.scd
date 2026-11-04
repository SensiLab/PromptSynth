// FM with sweeping filters and detune. Three detuned FM voices spread in stereo; a modulation
// envelope and a slow LFO move the FM index, and two filters (low-pass + band-pass) sweep in
// opposite directions, L and R out of phase. timbre = FM brightness/grit, sweep = filter centre.
// Warm: a sine sub and a 2nd-harmonic body under the FM, a gentler filter top, soft saturation.
// tinkle: a short bell of high inharmonic sines on each attack, a little apart in stereo.
// sub: a sine an octave down with phase distortion (it modulates its own phase); subPd = bite.
SynthDef(\fmSweep, { |out = 0, gate = 1, freq = 220, amp = 0.2, pan = 0,
	attack = 0.005, decay = 0.4, sustain = 0.5, release = 0.1,
	timbre = 0.4, sweep = 0.5, ratio = 2, detune = 0.3, lfoRate = 0.85, lfoDepth = 0.5,
	envAmt = 0.6, res = 0.3, warmth = 0.7, tinkle = 0.5, sub = 0.5, subPd = 0.4|
	var env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
	var menv = EnvGen.kr(Env.perc(0.003, decay * 1.5, 1, -4), gate);
	var lfo = SinOsc.kr(lfoRate, [0, pi]);           // stereo, out of phase
	var lfoSlow = LFTri.kr(lfoRate * 0.37);
	var index = timbre.linexp(0, 1, 0.2, 12) * (1 + (envAmt * menv * 2)) * (1 + (lfoDepth * 0.4 * lfoSlow));
	var voices = [-1, 0, 1].collect { |d, i|
		var f = freq * (d * detune * 0.25).midiratio;   // detune 1 = ±25 cents
		var mod = SinOsc.ar(f * ratio + (i * 0.4)) * f * index;
		SinOsc.ar(f + mod, 0, 1) + (SinOsc.ar(f * 0.5 + (mod * 0.3)) * 0.3)
	};
	var body = (SinOsc.ar(freq * 0.5) * 0.6 + (SinOsc.ar(freq, 0.5pi) * 0.5) + (SinOsc.ar(freq * 2) * 0.15)) * warmth;
	var pdSub = SinOsc.ar(freq * 0.5, 0) * sub * 2.9;
	var tenv =EnvGen.kr(Env.perc(0.001, 0.35, 1, -6), gate);
	var bell = [[4.0, 7.11, 10.93], [4.02, 7.07, 11.02]].collect { |rs|
		(rs.collect { |r, j| SinOsc.ar((freq * r).min(15000), 0, 0.5 / (j + 1)) }).sum
	} * tenv * tinkle * 0.5;
	var sig = Splay.ar(voices, 0.8, 1, pan) + Pan2.ar(body + pdSub.tanh, pan);
	var cf = sweep.linexp(0, 1, 200, 6000) * (1 + (envAmt * menv * 2.5));
	var lp = RLPF.ar(sig, (cf * (2 ** (lfo * lfoDepth * 1.5))).clip(60, 18000), res.linlin(0, 1, 0.9, 0.12));
	var bp = BPF.ar(sig, (cf * 1.6 * (2 ** (lfo.reverse * lfoDepth * -1.5))).clip(100, 14000), 0.35) * 2;
	sig = (lp + (bp * (1 - (warmth * 0.5)))) * 0.6;
	sig = LPF.ar(sig, warmth.linexp(0, 1, 16000, 5000));
	sig = (sig * 1.2).tanh + bell + pdSub;
	Out.ar(out, sig * env * amp);
}, metadata: (specs: (
	timbre: [0, 1], sweep: [0, 1], ratio: [0.5, 7], detune: [0, 1], lfoRate: [0.02, 8, \exp],
	lfoDepth: [0, 1], envAmt: [0, 1], res: [0, 1], warmth: [0, 1], tinkle: [0, 1], sub: [0, 1], subPd: [0, 1]
), map: (timbre: [\mouseX, 0, 1, \lin], sweep: [\mouseY, 0, 1, \lin])))
