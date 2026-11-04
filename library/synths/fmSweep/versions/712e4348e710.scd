// FM with sweeping filters and detune. Three detuned FM voices spread in stereo; a modulation
// envelope and a slow LFO move the FM index, and two filters (low-pass + band-pass) sweep in
// opposite directions, L and R out of phase. timbre = FM brightness/grit, sweep = filter centre.
SynthDef(\fmSweep, { |out = 0, gate = 1, freq = 220, amp = 0.2, pan = 0,
	attack = 0.005, decay = 0.4, sustain = 0.5, release = 0.8,
	timbre = 0.4, sweep = 0.5, ratio = 2, detune = 0.3, lfoRate = 0.85, lfoDepth = 0.5,
	envAmt = 0.6, res = 0.4|
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
	var sig = Splay.ar(voices, 0.8, 1, pan);
	var cf = sweep.linexp(0, 1, 250, 9000) * (1 + (envAmt * menv * 3));
	var lp = RLPF.ar(sig, (cf * (2 ** (lfo * lfoDepth * 1.5))).clip(60, 18000), res.linlin(0, 1, 0.9, 0.12));
	var bp = BPF.ar(sig, (cf * 1.6 * (2 ** (lfo.reverse * lfoDepth * -1.5))).clip(100, 14000), 0.35) * 2;
	sig = (lp + bp) * 0.6;
	sig = (sig * 1.4).tanh;
	Out.ar(out, sig * env * amp);
}, metadata: (specs: (
	timbre: [0, 1], sweep: [0, 1], ratio: [0.5, 7], detune: [0, 1], lfoRate: [0.02, 8, \exp],
	lfoDepth: [0, 1], envAmt: [0, 1], res: [0, 1]
)))
