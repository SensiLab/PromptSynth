// deadmau5-inspired Progressive House Track
// Featuring kick, hi-hat, snare, fat bass synth, and filtered reverb synth
// Structure: Intro -> Drop -> Outro

// Boot the server
s.boot;

// Set overall volume
s.volume = -3;

// PART 1: SYNTH DEFINITIONS
(
// Kick drum - punchy, clean kick with sub weight
SynthDef(\kick, {
    |out=0, amp=0.8, pan=0, dur=1|
    var sig, env, clickEnv, subEnv;

    // Sub oscillator envelope
    subEnv = EnvGen.ar(Env.perc(0.001, 0.4, 1, -8), doneAction: 2);

    // Body envelope with slightly longer decay
    env = EnvGen.ar(Env.perc(0.001, 0.25, 1, -4));

    // Click envelope for attack
    clickEnv = EnvGen.ar(Env.perc(0.0005, 0.01, 1, -4));

    // Sub sine wave with pitch envelope
    sig = SinOsc.ar(XLine.ar(150, 55, 0.04)) * subEnv * 0.7;

    // Body of kick
    sig = sig + (SinOsc.ar(XLine.ar(300, 80, 0.05)) * env * 0.5);

    // Click for attack
    sig = sig + (HPF.ar(WhiteNoise.ar, 500) * clickEnv * 0.2);

    // Output with level control
    sig = sig * amp;
    sig = Pan2.ar(sig, pan);

    Out.ar(out, sig);
}).add;

// Hi-hat - crisp digital hat with tunable pitch
SynthDef(\hihat, {
    |out=0, amp=0.3, pan=0, dur=1, openness=0.1|
    var sig, env;

    // Envelope with variable decay for open/closed hats
    env = EnvGen.ar(Env.perc(0.001, 0.05 + (openness * 0.5), 1, -20), doneAction: 2);

    // Mix of white and pink noise for different texture
    sig = WhiteNoise.ar(0.7) + PinkNoise.ar(0.3);

    // Bandpass filter to set the tone
    sig = BPF.ar(sig, 7000, 0.8);
    sig = HPF.ar(sig, 4000);

    // Output with level control
    sig = sig * env * amp;
    sig = Pan2.ar(sig, pan);

    Out.ar(out, sig);
}).add;

// Snare - layered snare with transient and body
SynthDef(\snare, {
    |out=0, amp=0.5, pan=0, dur=1|
    var sig, noiseEnv, sinEnv, noise, sine;

    // Noise envelope with longer decay for the tail
    noiseEnv = EnvGen.ar(Env.perc(0.001, 0.25, 1, -4), doneAction: 2);

    // Sine envelope for body
    sinEnv = EnvGen.ar(Env.perc(0.001, 0.15, 1, -4));

    // Filtered noise component
    noise = WhiteNoise.ar;
    noise = BPF.ar(noise, 1500, 1.5) * noiseEnv * 0.7;

    // Sine component for body
    sine = SinOsc.ar(180) * sinEnv * 0.3;

    // Mix components
    sig = noise + sine;

    // Output with level control
    sig = sig * amp;
    sig = Pan2.ar(sig, pan);

    Out.ar(out, sig);
}).add;

// Fat synth bass - inspired by deadmau5's saw basses
SynthDef(\fatBass, {
    |out=0, freq=110, amp=0.5, pan=0, gate=1, cutoff=2000, res=0.3, fatness=0.7|
    var sig, env, detuneFactor;

    // ADSR envelope
    env = EnvGen.kr(Env.adsr(0.01, 0.1, 0.7, 0.1), gate, doneAction: 2);

    // Detune factor for fatness
    detuneFactor = fatness * 0.02;

    // Multiple detuned saw oscillators
    sig = Saw.ar(freq * (1 - detuneFactor)) * 0.33;
    sig = sig + Saw.ar(freq) * 0.33;
    sig = sig + Saw.ar(freq * (1 + detuneFactor)) * 0.33;

    // Add sub oscillator for weight
    sig = sig + (SinOsc.ar(freq * 0.5) * 0.4);

    // Filter with envelope modulation
    sig = RLPF.ar(sig, cutoff * (env * 0.5 + 0.5), res);

    // Slight distortion for character
    sig = (sig * 1.5).tanh;

    // Output with level control
    sig = sig * env * amp;
    sig = Pan2.ar(sig, pan);

    Out.ar(out, sig);
}).add;

// Filtered reverb synth - pad/lead sound with filtering
SynthDef(\reverbSynth, {
    |out=0, freq=440, amp=0.4, pan=0, gate=1, attack=0.1, release=1,
    cutoff=2000, res=0.2, verbMix=0.5, verbRoom=0.8, verbDamp=0.5|
    var sig, env, verbSig;

    // ADSR envelope
    env = EnvGen.kr(Env.adsr(attack, 0.1, 0.8, release), gate, doneAction: 2);

    // Mix of pulse and saw waves
    sig = Pulse.ar(freq, 0.3) * 0.3;
    sig = sig + Saw.ar(freq * [0.995, 1, 1.005]) * 0.7;

    // Filter with envelope modulation
    sig = RLPF.ar(sig, cutoff * (env * 0.6 + 0.4), res);

    // Built-in reverb
    verbSig = FreeVerb2.ar(sig[0], sig[1], verbMix, verbRoom, verbDamp);
    sig = (sig * (1 - verbMix)) + (verbSig * verbMix);

    // Output with level control
    sig = sig * env * amp;
    sig = Balance2.ar(sig[0], sig[1], pan);

    Out.ar(out, sig);
}).add;
)
s.sync; // Wait for synths to be added

// PART 2: PATTERNS AND COMPOSITION
(
// Create clock and musical elements
~tempo = 128/60; // 128 BPM
~clock = TempoClock(~tempo);

// Scale for our bass and melody (F minor)
~scale = [41, 43, 44, 46, 48, 49, 51, 53]; // F minor
~root = 41; // F

// Bass pattern notes
~bassPattern1 = [0, 0, 0, 0, 0, 0, 0, 0, 3, 3, 3, 3, 3, 3, 3, 3]; // F -> A♭
~bassPattern2 = [0, 0, 5, 5, 0, 0, 5, 5, 3, 3, 8, 8, 3, 3, 8, 8]; // More complex pattern

// Synth pattern notes (melody)
~synthPattern1 = [7, 7, 8, 7, 14, 12, 8, 7]; // Simple melody
~synthPattern2 = [7, \rest, 7, 8, 12, \rest, 8, 7]; // With rests

// For storing pattern players
~players = Dictionary.new;

// Function to start the intro section
~startIntro = {
    "Starting intro section...".postln;

    // Sparse hat pattern
    ~players.put(\hatIntro, Pbind(
        \instrument, \hihat,
        \dur, Pseq([0.5, 0.5], inf),
        \amp, 0.15,
        \openness, Pseq([0.05, 0.2], inf),
        \pan, Pwhite(-0.1, 0.1, inf)
    ).play(~clock));

    // Very minimal kick
    ~players.put(\kickIntro, Pbind(
        \instrument, \kick,
        \dur, Pseq([1, 1, 1, 1], inf),
        \amp, 0.5,
        \pan, 0
    ).play(~clock));

    // Atmospheric pad with the filtered reverb synth
    ~players.put(\padIntro, Pbind(
        \instrument, \reverbSynth,
        \dur, 4,
        \legato, 1.2,
        \midinote, Pseq([~root, ~root+12], inf) + Pseq([0, 7], inf),
        \attack, 1.5,
        \release, 2.5,
        \cutoff, 800,
        \res, 0.2,
        \verbMix, 0.7,
        \verbRoom, 0.8,
        \verbDamp, 0.5,
        \amp, 0.3,
        \pan, Pseq([-0.3, 0.3], inf)
    ).play(~clock));

    // Schedule the drop after 16 bars (64 beats)
    ~clock.sched(64, {
        "Building up to drop...".postln;

        // Add a filtered noise riser
        ~players.put(\riser, {
            var sig, env;
            env = EnvGen.kr(Env([0, 1], [8]), doneAction: 2);
            sig = WhiteNoise.ar(0.8) * env * 0.2;
            sig = RLPF.ar(sig, 300 + (10000 * env), 0.5);
            sig = Pan2.ar(sig, 0);
        }.play);

        // Schedule the actual drop after 8 more beats
        ~clock.sched(8, {
            ~startDrop.value;
        });

        nil; // Don't reschedule
    });
};

// Function to start the drop section
~startDrop = {
    "Dropping into main section!".postln;

    // Stop intro players
    ~players[\hatIntro].stop;
    ~players[\kickIntro].stop;
    ~players[\padIntro].stop;
    ~players.removeAt(\hatIntro);
    ~players.removeAt(\kickIntro);
    ~players.removeAt(\padIntro);

    // Full kick pattern
    ~players.put(\kickMain, Pbind(
        \instrument, \kick,
        \dur, Pseq([1, 1, 1, 1], inf),
        \amp, 0.7,
        \pan, 0
    ).play(~clock));

    // Hi-hat pattern with variations
    ~players.put(\hatMain, Pbind(
        \instrument, \hihat,
        \dur, Pseq([0.25, 0.25, 0.25, 0.25], inf),
        \amp, Pseq([0.2, 0.15, 0.25, 0.15], inf) * 0.7,
        \openness, Pseq([0.05, 0.05, 0.2, 0.05], inf),
        \pan, Pwhite(-0.2, 0.2, inf)
    ).play(~clock));

    // Snare on beats 2 and 4
    ~players.put(\snareMain, Pbind(
        \instrument, \snare,
        \dur, Pseq([1, 1], inf),
        \amp, 0.5,
        \pan, 0
    ).play(~clock, quant: [2, 1])); // Start on beat 2

    // Fat bass playing the pattern
    ~players.put(\bassMain, Pbind(
        \instrument, \fatBass,
        \dur, 0.5,
        \legato, 0.8,
        \midinote, Pseq(~bassPattern2, inf) + ~root,
        \cutoff, Pseq([1800, 1600, 2200, 1600], inf),
        \res, 0.3,
        \fatness, 0.8,
        \amp, 0.45,
        \pan, 0
    ).play(~clock));

    // Lead synth with the melody
    ~players.put(\synthMain, Pbind(
        \instrument, \reverbSynth,
        \dur, Pseq([0.5, 0.5, 0.5, 0.5, 0.75, 0.75, 0.5, 0.5], inf),
        \legato, 0.8,
        \midinote, Pseq(~synthPattern2, inf) + ~root + 12,
        \attack, 0.01,
        \release, 0.3,
        \cutoff, Pseq([3000, 2500, 3500, 2500], inf),
        \res, 0.4,
        \verbMix, 0.3,
        \verbRoom, 0.6,
        \verbDamp, 0.5,
        \amp, 0.35,
        \pan, Pwhite(-0.3, 0.3, inf)
    ).play(~clock, quant: 4));

    // Schedule the outro after 32 bars (128 beats)
    ~clock.sched(128, {
        "Transitioning to outro...".postln;
        ~startOutro.value;
        nil; // Don't reschedule
    });
};

// Function to start the outro section
~startOutro = {
    "Starting outro section...".postln;

    // Gradually remove elements

    // Stop the bass first
    ~players[\bassMain].stop;
    ~players.removeAt(\bassMain);

    // Schedule stop for the lead synth
    ~clock.sched(8, {
        ~players[\synthMain].stop;
        ~players.removeAt(\synthMain);

        // Add outro pad
        ~players.put(\padOutro, Pbind(
            \instrument, \reverbSynth,
            \dur, 8,
            \legato, 1.2,
            \midinote, Pseq([~root, ~root+7, ~root+3, ~root+5], inf) + 12,
            \attack, 2.0,
            \release, 6.0,
            \cutoff, 1200,
            \res, 0.2,
            \verbMix, 0.8,
            \verbRoom, 0.9,
            \verbDamp, 0.2,
            \amp, 0.25,
            \pan, Pwhite(-0.5, 0.5, inf)
        ).play(~clock));

        nil;
    });

    // Simplify hi-hats after 16 beats
    ~clock.sched(16, {
        ~players[\hatMain].stop;
        ~players.removeAt(\hatMain);

        ~players.put(\hatOutro, Pbind(
            \instrument, \hihat,
            \dur, Pseq([0.5, 0.5], inf),
            \amp, 0.1,
            \openness, 0.1,
            \pan, 0
        ).play(~clock));

        nil;
    });

    // Simplify snare after 16 beats
    ~clock.sched(16, {
        ~players[\snareMain].stop;
        ~players.removeAt(\snareMain);

        nil;
    });

    // Simplify kick after 24 beats
    ~clock.sched(24, {
        ~players[\kickMain].stop;
        ~players.removeAt(\kickMain);

        ~players.put(\kickOutro, Pbind(
            \instrument, \kick,
            \dur, Pseq([2, 2], inf),
            \amp, 0.4,
            \pan, 0
        ).play(~clock));

        nil;
    });

    // Final fade out after 32 beats
    ~clock.sched(32, {
        "Fading out...".postln;

        // Stop remaining elements
        ~players.do({ |player| player.stop; });
        ~players.clear;

        // Add a final reverb tail
        {
            var sig = WhiteNoise.ar(0.1) * EnvGen.kr(Env.perc(0.001, 0.1));
            sig = FreeVerb.ar(sig, 1, 0.9, 0.1, 0.8);
            sig = sig * EnvGen.kr(Env.linen(0.1, 3, 5), doneAction: 2);
            Pan2.ar(sig, 0);
        }.play;

        "Track complete.".postln;
        nil;
    });
};

// Function to start the full track
~startTrack = {
    "Starting deadmau5-inspired track at 128 BPM...".postln;
    ~startIntro.value;
};

// Function to stop everything immediately
~stopTrack = {
    ~clock.clear;
    ~players.do({ |player| player.stop; });
    ~players.clear;
    "Track stopped.".postln;
};
)

// Execute this line to start the track
~startTrack.value;

// Execute this line to stop the track at any time
// ~stopTrack.value;