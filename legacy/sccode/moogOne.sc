(// Moog Model 1 inspired synth
SynthDef(\moogModel1, {
    |out=0, freq=440, amp=0.5, pan=0, gate=1,
    attack=0.01, decay=0.3, sustain=0.5, release=1,
    cutoff=1000, resonance=0.5,
    osc1Amp=1, osc2Amp=1, osc3Amp=1, noiseAmp=0,
    osc1Waveform=0, osc2Waveform=0, osc3Waveform=0,
    osc1Detune=0, osc2Detune=0, osc3Detune=0,
    lfoRate=1, lfoDepth=0, lfoDestination=0,
    filterEnvAmount=0, filterAttack=0.01, filterDecay=0.3, filterSustain=0.5, filterRelease=1|

    var sig, env, filterEnv, lfo, osc1, osc2, osc3, noise;

    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    filterEnv = EnvGen.kr(Env.adsr(filterAttack, filterDecay, filterSustain, filterRelease), gate);

    lfo = SinOsc.kr(lfoRate) * lfoDepth;

    osc1 = Select.ar(osc1Waveform, [
        SinOsc.ar(freq * (1 + osc1Detune)),
        Saw.ar(freq * (1 + osc1Detune)),
        Pulse.ar(freq * (1 + osc1Detune))
    ]) * osc1Amp;

    osc2 = Select.ar(osc2Waveform, [
        SinOsc.ar(freq * (1 + osc2Detune)),
        Saw.ar(freq * (1 + osc2Detune)),
        Pulse.ar(freq * (1 + osc2Detune))
    ]) * osc2Amp;

    osc3 = Select.ar(osc3Waveform, [
        SinOsc.ar(freq * (1 + osc3Detune)),
        Saw.ar(freq * (1 + osc3Detune)),
        Pulse.ar(freq * (1 + osc3Detune))
    ]) * osc3Amp;

    noise = WhiteNoise.ar() * noiseAmp;

    sig = (osc1 + osc2 + osc3 + noise) * 0.25;

    sig = MoogFF.ar(
        sig,
        Select.kr(lfoDestination, [
            cutoff + (filterEnv * filterEnvAmount),
            cutoff + (filterEnv * filterEnvAmount) + (lfo * 500)
        ]),
        resonance
    );

    sig = sig * env * amp;
    sig = Pan2.ar(sig, pan);
    Out.ar(out, sig);
}).add;
)
// 10 Example Patches

// 1. Classic Bass
(
    Synth(\moogModel1, [
        \freq, 255,
        \osc1Waveform, 1, \osc1Amp, 1,
        \osc2Waveform, 1, \osc2Amp, 0.5, \osc2Detune, 0.01,
        \cutoff, 800, \resonance, 0.3,
        \attack, 0.01, \decay, 0.1, \sustain, 0.8, \release, 0.5,
        \filterEnvAmount, 2000, \filterAttack, 0.01, \filterDecay, 0.1, \filterSustain, 0.2, \filterRelease, 0.3
    ]);
)
// 2. Sweeping Lead
(
    Synth(\moogModel1, [
        \freq, 440,
        \osc1Waveform, 2, \osc1Amp, 1,
        \osc2Waveform, 1, \osc2Amp, 0.7, \osc2Detune, 0.02,
        \cutoff, 2000, \resonance, 0.7,
        \attack, 0.05, \decay, 0.2, \sustain, 0.6, \release, 0.8,
        \lfoRate, 0.5, \lfoDepth, 1, \lfoDestination, 1
    ]);
)

// 3. Dirty Growl
(
    Synth(\moogModel1, [
        \freq, 110,
        \osc1Waveform, 1, \osc1Amp, 1,
        \osc2Waveform, 1, \osc2Amp, 1, \osc2Detune, 0.004,
        \osc3Waveform, 2, \osc3Amp, 0.5, \osc3Detune, -0.01,
        \noiseAmp, 0.1,
        \cutoff, 500, \resonance, 0.8,
        \attack, 0.01, \decay, 0.1, \sustain, 0.8, \release, 0.3,
        \filterEnvAmount, 3000, \filterAttack, 0.01, \filterDecay, 0.2, \filterSustain, 0.4, \filterRelease, 0.2
    ]);
)

// 4. Soft Pad
(
    Synth(\moogModel1, [
        \freq, 220,
        \osc1Waveform, 0, \osc1Amp, 1,
        \osc2Waveform, 0, \osc2Amp, 0.7, \osc2Detune, 0.01,
        \osc3Waveform, 0, \osc3Amp, 0.5, \osc3Detune, -0.01,
        \cutoff, 1200, \resonance, 0.2,
        \attack, 0.5, \decay, 0.3, \sustain, 0.7, \release, 1.5,
        \lfoRate, 0.2, \lfoDepth, 0.3, \lfoDestination, 1
    ]);
)

// 5. Percussive Pluck
(
    Synth(\moogModel1, [
        \freq, 330,
        \osc1Waveform, 2, \osc1Amp, 1,
        \osc2Waveform, 1, \osc2Amp, 0.6, \osc2Detune, 0.01,
        \cutoff, 3000, \resonance, 0.5,
        \attack, 0.001, \decay, 0.1, \sustain, 0.2, \release, 0.2,
        \filterEnvAmount, 5000, \filterAttack, 0.001, \filterDecay, 0.05, \filterSustain, 0.1, \filterRelease, 0.1
    ]);
)

// 6. Modulated Texture
(
    Synth(\moogModel1, [
        \freq, 165,
        \osc1Waveform, 1, \osc1Amp, 1,
        \osc2Waveform, 1, \osc2Amp, 1, \osc2Detune, 0.1,
        \osc3Waveform, 2, \osc3Amp, 0.7, \osc3Detune, -0.1,
        \cutoff, 1500, \resonance, 0.6,
        \attack, 0.2, \decay, 0.3, \sustain, 0.6, \release, 0.8,
        \lfoRate, 4, \lfoDepth, 0.5, \lfoDestination, 1,
        \filterEnvAmount, 2000, \filterAttack, 0.1, \filterDecay, 0.2, \filterSustain, 0.5, \filterRelease, 0.3
    ]);
)

// 7. Screaming Lead
(
    Synth(\moogModel1, [
        \freq, 660,
        \osc1Waveform, 1, \osc1Amp, 1,
        \osc2Waveform, 2, \osc2Amp, 0.8, \osc2Detune, 0.02,
        \cutoff, 4000, \resonance, 0.9,
        \attack, 0.05, \decay, 0.1, \sustain, 0.8, \release, 0.3,
        \filterEnvAmount, 3000, \filterAttack, 0.01, \filterDecay, 0.1, \filterSustain, 0.7, \filterRelease, 0.2
    ]);
)

// 8. Wobble Bass
(
    Synth(\moogModel1, [
        \freq, 55,
        \osc1Waveform, 1, \osc1Amp, 1,
        \osc2Waveform, 1, \osc2Amp, 1, \osc2Detune, 0.01,
        \cutoff, 500, \resonance, 0.7,
        \attack, 0.01, \decay, 0.1, \sustain, 0.8, \release, 0.2,
        \lfoRate, 5, \lfoDepth, 1, \lfoDestination, 1,
        \filterEnvAmount, 2000, \filterAttack, 0.01, \filterDecay, 0.1, \filterSustain, 0.5, \filterRelease, 0.1
    ]);

)

// 9. Ambient Drone
(
    Synth(\moogModel1, [
        \freq, 110,
        \osc1Waveform, 0, \osc1Amp, 1,
        \osc2Waveform, 0, \osc2Amp, 0.7, \osc2Detune, 0.02,
        \osc3Waveform, 0, \osc3Amp, 0.5, \osc3Detune, -0.02,
        \noiseAmp, 0.05,
        \cutoff, 1000, \resonance, 0.3,
        \attack, 2, \decay, 1, \sustain, 0.8, \release, 3,
        \lfoRate, 0.1, \lfoDepth, 0.3, \lfoDestination, 1
    ]);
)

// 10. Noisy FX
(
    Synth(\moogModel1, [
        \freq, 220,
        \osc1Waveform, 2, \osc1Amp, 0.5,
        \osc2Waveform, 2, \osc2Amp, 0.5, \osc2Detune, 0.1,
        \noiseAmp, 0.5,
        \cutoff, 3000, \resonance, 0.8,
        \attack, 0.01, \decay, 0.1, \sustain, 0.5, \release, 0.5,
        \lfoRate, 10, \lfoDepth, 1, \lfoDestination, 1,
        \filterEnvAmount, 4000, \filterAttack, 0.01, \filterDecay, 0.1, \filterSustain, 0.3, \filterRelease, 0.2
    ]);
)


(
// s.record;

Pdef(\a,
Pbind(
    \instrument, \moogModel1,
		\dur,0.25,
		\note, Pseq([0,5,2,9,4], inf),
		\octave, Pseq([2,3,4,5].stutter(2)+1, 4),
		\amp,0.5,

 \osc1Waveform, 2, \osc1Amp, 1,
        \osc2Waveform, 1, \osc2Amp, 0.6, \osc2Detune, 0.01,
        \cutoff, 3000, \resonance, 0.5,
        \attack, 0.001, \decay, 0.1, \sustain, 0.2, \release, 1.2,
        \filterEnvAmount, 5000, \filterAttack, 0.001, \filterDecay, 0.05, \filterSustain, 0.1, \filterRelease, 0.1
);
).play(quant:0.0);
)