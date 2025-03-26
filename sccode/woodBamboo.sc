(
SynthDef(\woodBamboo, {
    |out=0, freq=1000, ringTime=0.1, ringMix=0.5, noiseMix=0.5, amp=0.5|
    var exciter, resonator, noiseSig, output;
var freqs, amps, times;
	~makeBambooArrays = { |freq = 440|
    var freqs, amps, times;
    freqs = freq * [1.0, 3.93, 4.97, 6.23, 9.11];
    amps = [1.0, 0.5, 0.35, 0.18, 0.12];
    times = [1.8, 0.9, 0.7, 0.4, 0.2];
    [freqs, amps, times]
};

	#freq, amps, times = ~makeBambooArrays.(freq);
    exciter = Impulse.ar(0);
    resonator = Klank.ar(
       `[freq, amps, times],
        exciter
    );
    noiseSig = LPF.ar(PinkNoise.ar,9400) * EnvGen.ar(Env.perc(0.01, 0.01));
    output = (resonator * ringMix) + (noiseSig * noiseMix);
    output = output * EnvGen.ar(Env.perc(0.01, ringTime * 2), doneAction: 2);
    Out.ar(out, Pan2.ar(output, 0, amp));
}).add;
)




// Example usage:
Synth(\woodBamboo, [\freq, 1200, \ringTime, 0.1, \ringMix, 0.7, \noiseMix, 0.1, \amp, 0.5]);
Synth(\woodBamboo, [\freq, 800, \ringTime, 0.2, \ringMix, 0.8, \noiseMix, 0.2, \amp, 0.5]);
Synth(\woodBamboo, [\freq, 35.midicps, \ringTime, 1.7, \ringMix, 0.7, \noiseMix, 0.01, \amp, 2]);


(
Pbindef(\wba,
    \instrument, \woodBamboo,
    \dur, Pseq([0.25, 0.25, 0.25, 0.25, 0.25, 0.5] * 0.5, inf),
    \note, Pseq([0,-12,-24,4,9,14,19] - 12 , 8),
	\root, Pseq([0,3,-4,1].stutter(24), 1),//4
    \ringTime, Pwhite(0.1, 0.2),
    \ringMix, Pwhite(0.6, 0.8),
    \noiseMix, Pwhite(0.2, 0.3),
    \amp, Pwhite(0.7, 0.9)
).play(quant:0);
)


(
Pbind(
    \instrument, \woodBamboo,
    \dur, Pseq([
        Pseq([0.25, 0.25, 0.5, Rest(0.25), 0.25, 0.5], 2),
        Pseq([0.125, 0.125, 0.25, Rest(0.25), 0.25], 2),
        Pseq([1, Rest(0.5), 0.5, Rest(0.25), 0.25, 0.25, 0.25], 1)
    ], inf),
    \freq, Prand([
        Pseq([200, 250, 300]),
        Pseq([350, 400, 450]),
        Prand([500, 550, 600], 3)
    ], inf),
    \ringTime, Pseg(
        Pseq([0.05, 0.2, 0.05], inf),
        Pseq([4, 4], inf),
        \sine
    ),
    \ringMix, Pwhite(0.3, 0.7),
    \noiseMix, Pseg(
        Pseq([0.2, 0.8, 0.2], inf),
        Pseq([8, 8], inf),
        \sine
    ),
    \amp, Pseq([
        Pseq([0.6, 0.4, 0.5, 0.3], 3),
        Pseq([0.2, 0.3, 0.4, 0.5, 0.6], 1)
    ], inf) * Pwhite(0.8, 1.0)
).play;
)



(
Pbind(
	\note,  Pseg( Pseq([1, 5],inf), 4, \linear),
    \dur, 1
).play;
)



