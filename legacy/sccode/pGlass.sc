// Philip Glass-inspired composition
// Featuring additive processes, arpeggios, and minimalist repetition

// Boot the server
s.boot;
(
// SynthDef for a Glass-like sound with a piano/rhodes quality
SynthDef(\glassSound, {
    |out=0, freq=440, amp=0.3, pan=0, attack=0.01, decay=0.3, sustain=0.5, release=0.5, gate=1|
    var snd, env;

    // Classic Glass uses a lot of keyboard sounds
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);

    // Base sound: a slightly detuned oscillator mix
    snd = SinOsc.ar(freq) * 0.5;
    snd = snd + SinOsc.ar(freq * 2) * 0.25;
    snd = snd + SinOsc.ar(freq * 3) * 0.125;

    // Add some harmonics and slight "hardness" for the attack
    snd = snd + (LPF.ar(Pulse.ar(freq, 0.15), freq * 4) * EnvGen.kr(Env.perc(0.01, 1.5)) * 0.05);

    // Apply envelope and output
    snd = snd * env * amp;
    snd = Pan2.ar(snd, pan);

    Out.ar(out, snd);
}).add;
)
// Wait for SynthDef to be loaded
s.sync;

(
// Glass-like sequences - repetitive with gradual changes
// Typical Glass harmonies often use modal patterns and arpeggios
// I'll create a few different patterns that will interact

// Define some base arpeggios using common Glass chords
~glassArp1 = [60, 64, 67, 72, 76, 72, 67, 64]; // C major arpeggio (up and down)
~glassArp2 = [60, 64, 67, 70, 67, 64]; // C major with lowered 7th
~glassArp3 = [57, 60, 64, 67, 64, 60]; // C major in first inversion
~glassArp4 = [55, 59, 62, 67, 62, 59]; // G minor pattern

// Timing patterns - Glass often uses triplets and unusual subdivisions
~durPattern1 = [0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25]; // Steady eighth notes
~durPattern2 = [0.33, 0.33, 0.33, 0.33, 0.33, 0.33]; // Triplet feel
~durPattern3 = [0.125, 0.125, 0.25, 0.125, 0.125, 0.25]; // Additive pattern

// Pattern 1 - Main arpeggio pattern
~pattern1 = Pbind(
    \instrument, \glassSound,
    \midinote, Pseq([~glassArp1, ~glassArp1, ~glassArp2, ~glassArp1], inf),
    \dur, Pseq(~durPattern1, inf),
    \attack, 0.01,
    \decay, 0.1,
    \sustain, 0.2,
    \release, 0.5,
    \amp, 0.2,
    \pan, -0.3
);

// Pattern 2 - Secondary pattern with offset rhythm
~pattern2 = Pbind(
    \instrument, \glassSound,
    \midinote, Pseq([~glassArp3, ~glassArp3, ~glassArp4, ~glassArp3], inf),
    \dur, Pseq(~durPattern2, inf),
    \attack, 0.02,
    \decay, 0.1,
    \sustain, 0.3,
    \release, 0.4,
    \amp, 0.18,
    \pan, 0.3
);

// Pattern 3 - Bass pattern for foundation
~pattern3 = Pbind(
    \instrument, \glassSound,
    \midinote, Pseq([48, 48, 50, 43, 48, 48, 52, 43], inf),
    \dur, Pseq([0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5], inf),
    \attack, 0.05,
    \decay, 0.1,
    \sustain, 0.7,
    \release, 0.5,
    \amp, 0.25,
    \pan, 0
);

// Pattern 4 - High accent notes (added later)
~pattern4 = Pbind(
    \instrument, \glassSound,
    \midinote, Pseq([72, 76, 79, 84, 79, 76], inf),
    \dur, Pseq(~durPattern3 * 2, inf),
    \attack, 0.01,
    \decay, 0.2,
    \sustain, 0.1,
    \release, 0.3,
    \amp, 0.15,
    \pan, Pseq([-0.7, 0.7, -0.5, 0.5, 0, 0], inf)
);

// Array to store our players
~players = [];

// Function to start the Glass composition
~startGlass = {
    // Start with pattern 1
    ~players = ~players.add(~pattern1.play);

    // Add pattern 3 (bass) after 8 seconds
    SystemClock.sched(8, {
        ~players = ~players.add(~pattern3.play);
        "Adding bass line...".postln;
    });

    // Add pattern 2 after 16 seconds
    SystemClock.sched(16, {
        ~players = ~players.add(~pattern2.play);
        "Adding secondary arpeggio...".postln;
    });

    // Add pattern 4 (high notes) after 24 seconds
    SystemClock.sched(24, {
        ~players = ~players.add(~pattern4.play);
        "Adding high accent notes...".postln;
    });

    // After 40 seconds, start removing elements
    SystemClock.sched(40, {
        ~players[3].stop;
        ~players.removeAt(3);
        "Removing high accent notes...".postln;
    });

    // After 48 seconds, remove another element
    SystemClock.sched(48, {
        ~players[1].stop;
        ~players.removeAt(1);
        "Removing bass line...".postln;
    });

    // After 56 seconds, begin final fade
    SystemClock.sched(56, {
        ~players[0].stop;
        "Fading out...".postln;
        SystemClock.sched(4, {
            if(~players.size > 0) {
                ~players[0].stop;
                ~players = [];
            };
            "Composition complete.".postln;
        });
    });
};

// Function to stop the composition
~stopGlass = {
    ~players.do(_.stop);
    ~players = [];
    "Stopped.".postln;
};
)

// Execute this line to start the composition
~startGlass.value;

// Execute this line to stop the composition at any time
// ~stopGlass.value;