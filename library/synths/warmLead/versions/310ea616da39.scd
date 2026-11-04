// Warm lead: two detuned saws and a soft pulse, a sine sub, through a gentle resonant low-pass
// with its own envelope (a soft "bwow" at the start of each note), delayed vibrato, light drive
// and a small stereo chorus.
SynthDef(\warmLead, { |out = 0, gate = 1, freq = 440, amp = 0.2, pan = 0,
	attack = 0.01, decay = 0.35, sustain = 0.7, release = 0.25,
	cutoff = 1800, res = 0.25, fenv = 1.5, detune = 0.12, sub = 0.4, vib = 0.12, vibRate = 5.5, drive = 1.6|
	var env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
	var fe = EnvGen.kr(Env.perc(0.005, decay * 1.4, 1, -3), gate);
	var vibrato = SinOsc.kr(vibRate, 0, vib * EnvGen.kr(Env([0, 0, 1], [0.25, 0.4]))).midiratio;
	var f = freq * vibrato;
	var osc = Saw.ar(f * [detune.neg, detune].midiratio).sum * 0.5
		+ (Pulse.ar(f, 0.45) * 0.25) + (SinOsc.ar(f * 0.5) * sub);
	var cf = (cutoff * (2 ** (fe * fenv))).clip(80, 14000);
	var sig = RLPF.ar(osc, cf, res.linlin(0, 1, 0.9, 0.2));
	sig = (sig * drive).tanh / drive.sqrt;
	sig = LPF.ar(sig, 9000);
	sig = [sig, DelayC.ar(sig, 0.02, SinOsc.kr(0.3, [0, pi]).range(0.004, 0.012)).sum * 0.5] * [0.8, 0.8];
	sig = Balance2.ar(sig[0] + (sig[1] * 0.4), sig[1] + (sig[0] * 0.4), pan);
	Out.ar(out, sig * env * amp);
}, metadata: (specs: (
	cutoff: [200, 8000, \exp], res: [0, 1], fenv: [0, 4], detune: [0, 0.5], sub: [0, 1],
	vib: [0, 1], vibRate: [1, 10, \exp], drive: [1, 6, \exp]
)))
