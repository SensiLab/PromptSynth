// Steve Reich-inspired Marimba Composition (1 minute)
// Using Klank.ar for resonant marimba sound modeling
// Features phase shifting and additive rhythmic processes

// Boot the server
s.boot;

// Create an improved marimba synth using Klank
SynthDef(\marimbaKlank, {
    |out=0, freq=440, amp=0.3, pan=0, attack=0.005, decay=1.0, sustain=0|
    var exciter, sig, env;

    // Envelope for overall amplitude control
    env = EnvGen.kr(Env.perc(attack, decay), doneAction: 2);

    // Excitation signal - mallet strike
    exciter = Impulse.ar(0) * amp;

    // Resonant frequencies for marimba tone (carefully tuned to match marimba spectra)
    // Marimba resonators emphasize certain harmonics with specific amplitudes and decay times
    sig = Klank.ar(
        `[
            // Frequencies as harmonics of the fundamental
            [1, 3.932, 9.538, 13.248, 17.321],
            // Amplitudes of respective harmonics (marimba has strong transient but weak sustain)
            [1, 0.5, 0.25, 0.125, 0.06],
            // Decay times for each harmonic (higher harmonics decay faster in marimbas)
            [1, 0.7, 0.5, 0.3, 0.2] * decay
        ],
        exciter,
        freq
    );

    // Add subtle noise component for mallet attack
    sig = sig + (HPF.ar(PinkNoise.ar * EnvGen.kr(Env.perc(0.001, 0.01)), 800) * 0.05);

    // Apply global envelope and amplitude
    sig = sig * env;

    // Output with panning
    sig = Pan2.ar(sig, pan);
    Out.ar(out, sig);
}).add;

// Wait for SynthDef to load
s.sync;

(
// Reich's compositional principles:
// 1. Process-based minimalism with gradual transformation
// 2. Phasing technique with identical patterns going out of sync
// 3. Rhythmic displacement and pattern overlays

// Define scales and patterns
// Using D minor pentatonic for an authentic Reich sound (similar to his works like "Mallet Phase")
~scale = [62, 65, 67, 69, 74, 77] - 60; // D, F, G, A, D, F

// Define rhythmic patterns inspired by Reich's "Nagoya Marimbas" and "Six Marimbas"
~patternA = [0, 2, 4, 2, 3, 1, 2, 0];
~patternB = [4, 2, 3, 4, 0, 2, 1, 3];
~patternC = [2, 4, 5, 4, 3, 2, 0, 1];

// Define note durations (rhythmic patterns)
~dursA = [0.25, 0.25, 0.5, 0.25, 0.25, 0.5, 0.5, 0.5];
~dursB = [0.5, 0.25, 0.25, 0.5, 0.25, 0.25, 0.5, 0.5];
~dursC = [0.25, 0.25, 0.25, 0.25, 0.5, 0.5, 0.5, 0.5];

// Create TempoClock
~tempo = 140/60; // 140 BPM (medium tempo typical for Reich's marimba works)
~clock = TempoClock(~tempo);

// Store our pattern players
~players = [];

// Function to start the composition
~startReich = {
    "Starting Steve Reich marimba composition (1 minute)...".postln;

    // First marimba pattern - right speaker
    ~players = ~players.add(
        Pbind(
            \instrument, \marimbaKlank,
            \scale, ~scale,
            \degree, Pseq(~patternA, inf),
            \dur, Pseq(~dursA, inf),
            \decay, 1.5,
            \amp, 0.35,
            \pan, 0.7
        ).play(~clock)
    );

    // After 5 seconds, add second marimba with same pattern - left speaker
    ~clock.sched(5, {
        ~players = ~players.add(
            Pbind(
                \instrument, \marimbaKlank,
                \scale, ~scale,
                \degree, Pseq(~patternA, inf),
                \dur, Pseq(~dursA, inf),
                \decay, 1.5,
                \amp, 0.35,
                \pan, -0.7
            ).play(~clock)
        );
        "Adding second voice...".postln;
    });

    // After 10 seconds, begin phase shifting the second marimba
    ~clock.sched(10, {
        ~players[1].stop;
        ~players[1] = Pbind(
            \instrument, \marimbaKlank,
            \scale, ~scale,
            \degree, Pseq(~patternA, inf),
            \dur, Pseq(~dursA * 1.02, inf),  // 2% longer durations creates gradual phasing
            \decay, 1.5,
            \amp, 0.35,
            \pan, -0.7
        ).play(~clock);
        "Beginning phase shifting...".postln;
    });

    // After 20 seconds, add third pattern in center
    ~clock.sched(20, {
        ~players = ~players.add(
            Pbind(
                \instrument, \marimbaKlank,
                \scale, ~scale,
                \degree, Pseq(~patternB, inf),
                \dur, Pseq(~dursB, inf),
                \decay, 1.3,
                \amp, 0.3,
                \pan, 0
            ).play(~clock)
        );
        "Adding contrasting pattern (third voice)...".postln;
    });

    // After 30 seconds, shift third pattern down an octave for bass support
    ~clock.sched(30, {
        ~players[2].stop;
        ~players[2] = Pbind(
            \instrument, \marimbaKlank,
            \scale, ~scale,
            \degree, Pseq(~patternB, inf) - 7, // Down an octave
            \dur, Pseq(~dursB, inf),
            \decay, 2.0, // Longer decay for lower notes
            \amp, 0.4,
            \pan, 0
        ).play(~clock);
        "Developing third voice...".postln;
    });

    // After 40 seconds, add fourth pattern (climax of piece)
    ~clock.sched(40, {
        ~players = ~players.add(
            Pbind(
                \instrument, \marimbaKlank,
                \scale, ~scale,
                \degree, Pseq(~patternC, inf),
                \dur, Pseq(~dursC, inf),
                \decay, 1.2,
                \amp, 0.3,
                \pan, 0.3
            ).play(~clock)
        );
        "Adding fourth voice (building to climax)...".postln;
    });

    // After 50 seconds, begin removing voices for conclusion
    ~clock.sched(50, {
        ~players[1].stop; // Stop second voice (the phase-shifted one)
        ~players.removeAt(1);
        "Beginning conclusion, removing second voice...".postln;
    });

    // After 53 seconds, remove another voice
    ~clock.sched(53, {
        ~players[1].stop; // Now the third voice becomes index 1
        ~players.removeAt(1);
        "Removing another voice...".postln;
    });

    // After 56 seconds, begin final pattern
    ~clock.sched(56, {
        ~players[0].stop;
        ~players.removeAt(0);

        // Final concluding pattern
        ~players = ~players.add(
            Pbind(
                \instrument, \marimbaKlank,
                \scale, ~scale,
                \degree, Pseq([0, 2, 4, 5, 4, 2, 0], 1), // Closing melodic figure
                \dur, Pseq([0.5, 0.5, 0.5, 0.75, 0.75, 0.5, 1.0], 1),
                \decay, Pseq([1.5, 1.5, 1.5, 1.7, 1.7, 2.0, 3.0], 1), // Increasing decay for final notes
                \amp, Pseq([0.35, 0.35, 0.35, 0.3, 0.3, 0.25, 0.2], 1), // Gentle fade
                \pan, 0
            ).play(~clock)
        );
        "Final sequence...".postln;
    });

    // Clean up after 60 seconds (1 minute)
    ~clock.sched(60, {
        ~players.do(_.stop);
        ~players = [];
        "Composition complete.".postln;
    });
};

// Function to stop everything immediately
~stopReich = {
    ~players.do(_.stop);
    ~players = [];
    "Stopped.".postln;
};
)

// Run this to start the composition (1 minute)
s.record;
~startReich.value;

// Run this to stop immediately if needed
// ~stopReich.value;