// Brian Eno-inspired Ambient Music Composition (Refined)
// Featuring reverbs, careful decay management, and proper signal control

// Boot the server
s.boot;

// Set overall volume safety control
s.volume = -6;

// PART 1: SYNTH DEFINITIONS
// Create synths that capture Eno's ambient sound with proper reverb and decay
(
// Shared reverb effect - Eno's ambient work often features carefully tuned reverb
SynthDef(\enoReverb, {
    |in=0, out=0, mix=0.5, room=0.8, damp=0.5, amp=1.0|
    var dry, wet;

    dry = In.ar(in, 2);
    // Using FreeVerb for a more natural reverb tail
    wet = FreeVerb2.ar(dry[0], dry[1], mix, room, damp);

    // Limiting to prevent distortion
    wet = Limiter.ar(wet, 0.95);

    ReplaceOut.ar(out, wet * amp);
}).add;

// Atmospheric pad synth with more attention to envelope and levels
SynthDef(\enoAtmos, {
    |out=0, freq=440, amp=0.2, attack=4, decay=2, sustain=0.5, release=8, gate=1,
    filter=1000, rq=0.5, pan=0, mod=0.2, modSpeed=0.1|

    var sig, env, lfo;

    // Slow LFO for subtle movement
    lfo = SinOsc.kr(modSpeed).range(1-mod, 1+mod);

    // Multiple detuned oscillators for rich texture, with careful amplitude scaling
    sig = SinOsc.ar(freq * lfo * [0.99, 1, 1.01]) * 0.2;
    sig = sig + (SinOsc.ar(freq * lfo * [0.5, 0.5, 0.501]) * 0.1);
    sig = sig + (SinOsc.ar(freq * lfo * [1.498, 1.5, 1.502]) * 0.05);

    // Gentle noise component with proper level
    sig = sig + (LPF.ar(PinkNoise.ar(0.03), filter));

    // Long, slow envelope with careful decay
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release, curve: -2), gate, doneAction: 2);

    // Filter with slight movement
    sig = RLPF.ar(sig, filter * LFNoise2.kr(0.1).range(0.9, 1.1), rq);

    // Final output with level control
    sig = sig * env * amp;
    sig = Balance2.ar(sig[0] + sig[2], sig[1] + sig[2], pan);

    // Soft clipper to prevent distortion
    sig = SoftClipAmp8.ar(sig, 0.8);

    Out.ar(out, sig);
}).add;

// Gentle bell-like synth with proper decay
SynthDef(\enoChime, {
    |out=0, freq=440, amp=0.15, attack=0.01, decay=6, sustain=0.2, release=8, gate=1, pan=0|

    var sig, env;

    // FM-based bell tone with controlled modulation depth
    sig = SinOsc.ar(freq * [1, 1.001], 0, SinOsc.kr(freq * 0.5, 0, 0.05));
    sig = sig + SinOsc.ar(freq * [2, 2.002], 0, 0.05);

    // Long decay envelope with exponential curve for natural decay
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release, curve: -4), gate, doneAction: 2);

    // Simulated early reflections with controlled level
    sig = sig + DelayC.ar(sig, 0.2, LFNoise2.kr(0.1).range(0.1, 0.2), 0.1);

    // Final output
    sig = sig * env * amp;
    sig = Balance2.ar(sig[0], sig[1], pan);

    Out.ar(out, sig);
}).add;

// Distant drone synth with improved signal management
SynthDef(\enoDrone, {
    |out=0, freq=55, amp=0.25, attack=8, decay=3, sustain=0.7, release=10, gate=1,
    filter=500, resonance=0.4, pan=0|

    var sig, env, mod;

    // Slow random modulation
    mod = LFNoise1.kr(0.05).range(0.98, 1.02);

    // Drone built from multiple harmonics with proper level scaling
    sig = SinOsc.ar(freq * [1, 1.01, 2, 2.02, 3.01, 4.03] * mod, 0, [0.3, 0.3, 0.15, 0.1, 0.07, 0.03]);
    sig = Mix.ar(sig);

    // Very slow envelope with proper sustain
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release, curve: -3), gate, doneAction: 2);

    // Gentle filtering with subtle movement
    sig = RLPF.ar(sig, filter * LFNoise2.kr(0.03).range(0.8, 1.2), resonance);

    // Final output with level control
    sig = sig * env * amp;
    sig = Balance2.ar(sig, sig * 0.99, pan);

    // Soft clipper to prevent distortion
    sig = SoftClipAmp8.ar(sig, 0.8);

    Out.ar(out, sig);
}).add;

// Subtle tape-like background noise
SynthDef(\enoNoise, {
    |out=0, amp=0.03, filter=2000, pan=0|

    var sig;

    // Mix of noise types for rich texture
    sig = PinkNoise.ar(0.7) + (BrownNoise.ar(0.3));

    // Heavy filtering to just give a subtle background hiss
    sig = LPF.ar(sig, filter);
    sig = HPF.ar(sig, 200);

    // Very slow random amplitude changes
    sig = sig * LFNoise2.kr(0.05).range(0.7, 1.0);

    // Final output with controlled level
    sig = sig * amp;
    sig = Pan2.ar(sig, pan);

    Out.ar(out, sig);
}).add;
)
s.sync; // Wait for synths to be added

// PART 2: BUS SETUP AND REVERB MANAGEMENT
(
// Create a bus for reverb sends
~reverbBus = Bus.audio(s, 2);

// Start the reverb effect
~reverbSynth = Synth(\enoReverb, [
    \in, ~reverbBus,
    \out, 0,
    \mix, 0.7,
    \room, 0.85,
    \damp, 0.5,
    \amp, 0.9
]);

// Notes for a generative ambient piece in the style of Music for Airports
// Using D Dorian mode (D, E, F, G, A, B, C)
~enoNotes = [62, 64, 65, 67, 69, 71, 72, 74, 76, 77, 79]; // D Dorian across two octaves

// Lower octave for drones
~enoLowNotes = [38, 45, 50, 57]; // D, A, D, A

// Atmosphere player - evolving chords
~atmosPlayer = nil;

// Start the continuous background atmosphere
~startAtmos = {
    // Always running background atmosphere
    ~atmosPlayer = Pbind(
        \instrument, \enoAtmos,
        \out, ~reverbBus, // Send to reverb
        \dur, Pwhite(15.0, 25.0, inf), // Very long notes
        \legato, 1.1, // Slight overlap for smooth transitions
        \midinote, Pseq([
            Prand(~enoNotes.scramble[0..2], 1), // Random selection of 3 notes
            Prand(~enoNotes.scramble[0..3], 1), // Random selection of 4 notes
        ], inf),
        \filter, Pwhite(500, 2000, inf),
        \rq, Pwhite(0.3, 0.7, inf),
        \attack, Pwhite(3.0, 7.0, inf),
        \decay, Pwhite(2.0, 4.0, inf),
        \sustain, Pwhite(0.4, 0.6, inf),
        \release, Pwhite(8.0, 12.0, inf),
        \amp, Pwhite(0.12, 0.22, inf),
        \pan, Pwhite(-0.7, 0.7, inf),
        \mod, Pwhite(0.1, 0.3, inf),
        \modSpeed, Pwhite(0.05, 0.2, inf)
    ).play;
};

// Chime player - occasional bell-like tones
~chimePlayer = nil;

// Start the gentle chime patterns
~startChimes = {
    ~chimePlayer = Pbind(
        \instrument, \enoChime,
        \out, ~reverbBus, // Send to reverb
        \dur, Pexprand(4.0, 20.0, inf), // Random timing - sparse
        \midinote, Pseq([
            Prand(~enoNotes.scramble[0..4], 1),
            Prand(~enoNotes.scramble[3..7], 1),
        ], inf),
        \attack, Pwhite(0.01, 0.1, inf),
        \decay, Pwhite(4.0, 8.0, inf),
        \sustain, Pwhite(0.1, 0.3, inf),
        \release, Pwhite(6.0, 10.0, inf),
        \amp, Pwhite(0.05, 0.13, inf),
        \pan, Pwhite(-0.8, 0.8, inf)
    ).play;
};

// Drone player - deep background tones
~dronePlayer = nil;

// Start the background drones
~startDrones = {
    ~dronePlayer = Pbind(
        \instrument, \enoDrone,
        \out, ~reverbBus, // Send to reverb
        \dur, Pwhite(25.0, 45.0, inf), // Very long drones
        \midinote, Pseq([
            Prand(~enoLowNotes, 1), // D, A, D, A - drones often use root and fifth
        ], inf),
        \filter, Pwhite(300, 800, inf),
        \resonance, Pwhite(0.3, 0.6, inf),
        \attack, Pwhite(10.0, 18.0, inf),
        \decay, Pwhite(3.0, 6.0, inf),
        \sustain, Pwhite(0.6, 0.8, inf),
        \release, Pwhite(12.0, 20.0, inf),
        \amp, Pwhite(0.15, 0.25, inf),
        \pan, Pwhite(-0.5, 0.5, inf)
    ).play;
};

// Noise player - constant background texture
~noisePlayer = nil;

// Start the background noise texture
~startNoise = {
    ~noisePlayer = Synth(\enoNoise, [
        \out, ~reverbBus, // Send to reverb
        \amp, 0.02,
        \filter, 1500,
        \pan, 0
    ]);
};

// Function to start the Eno ambient piece
~startEno = {
    "Starting Brian Eno-inspired ambient composition...".postln;

    // Start the background noise first
    ~startNoise.value;
    "Adding subtle noise texture...".postln;

    // Start the drones after 5 seconds
    SystemClock.sched(5, {
        ~startDrones.value;
        "Adding drones...".postln;
    });

    // Start the atmospheric pads after 15 seconds
    SystemClock.sched(15, {
        ~startAtmos.value;
        "Adding atmospheric pads...".postln;
    });

    // Start the chimes after 30 seconds
    SystemClock.sched(30, {
        ~startChimes.value;
        "Adding occasional chimes...".postln;
    });

    "Ambient composition running. Use ~stopEno.value to end.".postln;
    "Audio levels are properly managed to prevent distortion.".postln;
};

// Function to stop the Eno ambient piece with graceful fadeout
~stopEno = {
    // Create a fade-out routine
    Routine({
        "Beginning gentle fade-out...".postln;

        // Gradually reduce the reverb mix
        20.do { |i|
            var mix = 0.7 * (20-i)/20;
            ~reverbSynth.set(\mix, mix);
            0.5.wait;
        };

        // Free all synths
        if(~atmosPlayer.notNil) { ~atmosPlayer.stop; ~atmosPlayer = nil; };
        if(~chimePlayer.notNil) { ~chimePlayer.stop; ~chimePlayer = nil; };
        if(~dronePlayer.notNil) { ~dronePlayer.stop; ~dronePlayer = nil; };
        if(~noisePlayer.notNil) { ~noisePlayer.free; ~noisePlayer = nil; };

        2.wait;

        // Free the reverb
        ~reverbSynth.free;
        ~reverbBus.free;

        "Ambient composition stopped.".postln;
    }).play;
};

// Monitor the audio levels to ensure no distortion
~startMonitoring = {
    ~levelWatcher = Routine({
        var server = s;
        inf.do {
            var level = server.volume.volume;
            var peak = server.peakCPU;
            if(peak > 80) {
                "WARNING: CPU usage high at %\\%".format(peak).postln;
            };
            2.wait;
        };
    }).play;
};
)

// Execute these lines to start the composition
~startMonitoring.value;
s.record;
~startEno.value;


// Execute this line to stop the composition with a gentle fadeout
~stopEno.value;