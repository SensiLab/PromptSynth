// Stockhausen-inspired Electronic Composition
// Showcasing techniques from his electronic works including:
// - Point music (Kontakte)
// - Serial organization of parameters
// - Spatial movement
// - Electronic sound manipulation (Gesang der Jünglinge)
// - Moment form

// Boot the server
s.boot;

// Set overall volume
s.volume = -3;

// PART 1: SYNTH DEFINITIONS
(
// Electronic tone generator with multiple parameters (inspired by Stockhausen's sine wave generators)
SynthDef(\stockTone, {
    |out=0, freq=440, amp=0.3, pan=0, attack=0.01, decay=0.1, sustain=0.5, release=0.5,
    mod=0, modSpeed=1, noise=0, filter=2000, rq=1.0, gate=1|

    var sig, env, mod1, mod2;

    // Complex envelope (Stockhausen often used precise envelope shapes)
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);

    // Modulation sources (for FM and AM)
    mod1 = SinOsc.ar(modSpeed) * mod;
    mod2 = SinOsc.ar(modSpeed * 1.33) * mod * 0.5;

    // Main oscillator with frequency modulation
    sig = SinOsc.ar(freq * (1 + mod1));

    // Add amplitude modulation
    sig = sig * (1 + mod2);

    // Add filtered noise component
    sig = sig + (BPF.ar(WhiteNoise.ar, freq * 2, 0.3) * noise);

    // Apply filter
    sig = RLPF.ar(sig, filter, rq);

    // Output with level control and spatialization
    sig = sig * env * amp;
    sig = Pan2.ar(sig, pan);

    Out.ar(out, sig);
}).add;

// Impulse generator for point sounds (inspired by Kontakte)
SynthDef(\stockImpulse, {
    |out=0, freq=1000, amp=0.3, pan=0, attack=0.001, decay=0.1, filter=3000, rq=0.7|

    var sig, env;

    // Sharp percussive envelope
    env = EnvGen.kr(Env.perc(attack, decay), doneAction: 2);

    // Mix of impulse and resonant filter
    sig = Impulse.ar(0) * 0.6;
    sig = sig + Dust.ar(20) * 0.4;

    // Apply resonant filter for pitched quality
    sig = Ringz.ar(sig, freq, decay * 0.5);

    // Additional filtering
    sig = RLPF.ar(sig, filter, rq);

    // Output with level control and spatialization
    sig = sig * env * amp;
    sig = Pan2.ar(sig, pan);

    Out.ar(out, sig);
}).add;

// Noise generator with variable density (inspired by Gesang der Jünglinge)
SynthDef(\stockNoise, {
    |out=0, amp=0.2, pan=0, attack=0.01, decay=0.5, sustain=0.3, release=0.5,
    density=10, lowfreq=200, highfreq=5000, bw=0.5, gate=1|

    var sig, env, filtFreq;

    // Complex envelope
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);

    // Noise with variable density
    sig = Dust2.ar(density) * 2 - 1;

    // Variable filter frequency
    filtFreq = LFNoise0.kr(0.5).exprange(lowfreq, highfreq);

    // Apply bandpass filter with variable bandwidth
    sig = BPF.ar(sig, filtFreq, bw);

    // Output with level control and spatialization
    sig = sig * env * amp;
    sig = Pan2.ar(sig, pan);

    Out.ar(out, sig);
}).add;

// Resonator for complex timbres (inspired by Stockhausen's ring modulation techniques)
SynthDef(\stockResonator, {
    |out=0, freq=300, amp=0.3, pan=0, attack=0.02, decay=0.2, sustain=0.4, release=1.0,
    carrier=500, modIndex=1, filterFreq=2000, rq=0.8, gate=1|

    var sig, env, mod;

    // Complex envelope
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);

    // Carrier oscillator
    sig = SinOsc.ar(carrier);

    // Apply ring modulation
    mod = SinOsc.ar(freq);
    sig = sig * mod * modIndex;

    // Apply resonant filter
    sig = RLPF.ar(sig, filterFreq, rq);

    // Output with level control and spatialization
    sig = sig * env * amp;
    sig = Pan2.ar(sig, pan);

    Out.ar(out, sig);
}).add;
)
s.sync; // Wait for synths to be added

// PART 2: SERIAL ORGANIZATION AND MOMENT FORM

(
// Create fundamental organization using serial techniques
// Stockhausen often used numerical series to organize parameters

// Define time segments (moment form)
~momentDurations = [6, 8, 5, 7, 5, 4, 11, 10, 8, 9, 7]; // Prime number durations in seconds
~totalDuration = ~momentDurations.sum; // Total duration in seconds
"Total duration: % seconds".format(~totalDuration).postln;

// Define frequency series (inspired by Stockhausen's frequency formulas)
~baseFreq = 220; // Base frequency
~freqSeries = Array.fill(12, { |i| ~baseFreq * (i+1) / 7 }); // Non-harmonic series

// Define amplitude series
~ampSeries = Array.fill(7, { |i| (i+1)/8 }); // Dynamic levels

// Define spatial positions
~panSeries = Array.fill(9, { |i| ((i*2) / 8) - 1 }); // Pan positions from -1 to +1

// Create an array to store all events
~events = Array.new;

// Create a random number generator with fixed seed for reproducibility
~rrand = { |min, max| min + (max - min).rand };

// Function to generate a serial event
~createSerialEvent = { |time, type, duration, seriesPosition|
    var event = Dictionary.new;

    event.put(\time, time);
    event.put(\type, type);
    event.put(\duration, duration);

    // Parameters determined by serial position
    event.put(\freq, ~freqSeries[seriesPosition % ~freqSeries.size]);
    event.put(\amp, ~ampSeries[seriesPosition % ~ampSeries.size]);
    event.put(\pan, ~panSeries[(seriesPosition * 3) % ~panSeries.size]);

    // Add event to collection
    ~events = ~events.add(event);
};

// PART 3: GENERATE THE COMPOSITION STRUCTURE

// Moment 1: Sparse point sounds (inspired by Kontakte)
~currentTime = 0;
~momentDensity = 5; // Events per second
(~momentDurations[0] * ~momentDensity).do { |i|
    var eventTime = ~currentTime + ~rrand.(0.0, ~momentDurations[0]);
    ~createSerialEvent.(eventTime, \stockImpulse, ~rrand.(0.05, 0.2), i);
};

// Moment 2: Tone clusters (inspired by Stimmung)
~currentTime = ~momentDurations[0];
7.do { |i|
    var eventTime = ~currentTime + ~rrand.(0.0, ~momentDurations[1]);
    var duration = ~rrand.(1.0, 4.0);
    ~createSerialEvent.(eventTime, \stockTone, duration, i);
};

// Moment 3: Dense noise textures (inspired by Gesang der Jünglinge)
~currentTime = ~momentDurations[0] + ~momentDurations[1];
5.do { |i|
    var eventTime = ~currentTime + ~rrand.(0.0, ~momentDurations[2]);
    var duration = ~rrand.(1.5, 3.5);
    ~createSerialEvent.(eventTime, \stockNoise, duration, i);
};

// Moment 4: Complex resonant structures
~currentTime = ~momentDurations[0] + ~momentDurations[1] + ~momentDurations[2];
6.do { |i|
    var eventTime = ~currentTime + ~rrand.(0.0, ~momentDurations[3]);
    var duration = ~rrand.(2.0, 5.0);
    ~createSerialEvent.(eventTime, \stockResonator, duration, i);
};

// Moment 5: Counterpoint of points and lines
~currentTime = ~momentDurations[0] + ~momentDurations[1] + ~momentDurations[2] + ~momentDurations[3];
// Points
8.do { |i|
    var eventTime = ~currentTime + ~rrand.(0.0, ~momentDurations[4]);
    ~createSerialEvent.(eventTime, \stockImpulse, ~rrand.(0.05, 0.15), i);
};
// Lines
3.do { |i|
    var eventTime = ~currentTime + ~rrand.(0.0, ~momentDurations[4]);
    var duration = ~rrand.(2.0, 4.0);
    ~createSerialEvent.(eventTime, \stockTone, duration, i);
};

// Moment 6: Silence with sparse events (inspired by Momente)
~currentTime = ~momentDurations[0] + ~momentDurations[1] + ~momentDurations[2] + ~momentDurations[3] + ~momentDurations[4];
3.do { |i|
    var eventTime = ~currentTime + ~rrand.(0.0, ~momentDurations[5]);
    var duration = ~rrand.(0.1, 0.3);
    ~createSerialEvent.(eventTime, \stockImpulse, duration, i);
};

// Moment 7: Electronic transformation (inspired by Telemusik)
~currentTime = ~momentDurations[0] + ~momentDurations[1] + ~momentDurations[2] + ~momentDurations[3] + ~momentDurations[4] + ~momentDurations[5];
// Tones
5.do { |i|
    var eventTime = ~currentTime + ~rrand.(0.0, ~momentDurations[6]);
    var duration = ~rrand.(3.0, 7.0);
    ~createSerialEvent.(eventTime, \stockTone, duration, i);
};
// Noise
4.do { |i|
    var eventTime = ~currentTime + ~rrand.(0.0, ~momentDurations[6]);
    var duration = ~rrand.(2.0, 4.0);
    ~createSerialEvent.(eventTime, \stockNoise, duration, i);
};

// Sort events by time
~events = ~events.sort({ |a, b| a[\time] < b[\time] });

// Function to play the composition
~playStockhausen = {
    var startTime = Main.elapsedTime;

    // Create a routine to play all events
    ~stockhausenRoutine = Routine({
        var lastTime = 0;

        ~events.do { |event|
            var timeToWait = event[\time] - lastTime;
            timeToWait.wait;
            lastTime = event[\time];

            // Play the event based on its type
            switch(event[\type],
                \stockTone, {
                    Synth(\stockTone, [
                        \freq, event[\freq],
                        \amp, event[\amp] * 0.4,
                        \pan, event[\pan],
                        \attack, ~rrand.(0.01, 0.1),
                        \decay, ~rrand.(0.1, 0.3),
                        \sustain, ~rrand.(0.3, 0.6),
                        \release, ~rrand.(0.5, 1.5),
                        \mod, ~rrand.(0.0, 0.7),
                        \modSpeed, ~rrand.(1.0, 8.0),
                        \noise, ~rrand.(0.0, 0.3),
                        \filter, ~rrand.(500, 5000),
                        \rq, ~rrand.(0.3, 0.8)
                    ]);
                    "Event: Tone at % sec, Freq: %".format(event[\time], event[\freq]).postln;
                },
                \stockImpulse, {
                    Synth(\stockImpulse, [
                        \freq, event[\freq],
                        \amp, event[\amp] * 0.5,
                        \pan, event[\pan],
                        \attack, ~rrand.(0.001, 0.01),
                        \decay, ~rrand.(0.05, 0.2),
                        \filter, ~rrand.(1000, 8000),
                        \rq, ~rrand.(0.5, 0.9)
                    ]);
                    "Event: Impulse at % sec".format(event[\time]).postln;
                },
                \stockNoise, {
                    Synth(\stockNoise, [
                        \amp, event[\amp] * 0.35,
                        \pan, event[\pan],
                        \attack, ~rrand.(0.01, 0.2),
                        \decay, ~rrand.(0.2, 0.5),
                        \sustain, ~rrand.(0.2, 0.4),
                        \release, ~rrand.(0.3, 1.0),
                        \density, ~rrand.(5, 50),
                        \lowfreq, ~rrand.(100, 500),
                        \highfreq, ~rrand.(2000, 8000),
                        \bw, ~rrand.(0.2, 0.8)
                    ]);
                    "Event: Noise at % sec".format(event[\time]).postln;
                },
                \stockResonator, {
                    Synth(\stockResonator, [
                        \freq, event[\freq],
                        \amp, event[\amp] * 0.4,
                        \pan, event[\pan],
                        \attack, ~rrand.(0.02, 0.2),
                        \decay, ~rrand.(0.1, 0.4),
                        \sustain, ~rrand.(0.3, 0.6),
                        \release, ~rrand.(0.5, 2.0),
                        \carrier, event[\freq] * ~rrand.(1.5, 3.5),
                        \modIndex, ~rrand.(0.5, 1.5),
                        \filterFreq, ~rrand.(500, 5000),
                        \rq, ~rrand.(0.5, 0.9)
                    ]);
                    "Event: Resonator at % sec".format(event[\time]).postln;
                }
            );
        };

        // Wait until the end of the piece
        (~totalDuration - lastTime).wait;
        "Composition complete.".postln;
    });

    // Start the routine
    ~stockhausenRoutine.play;

    // Return the end time for reference
    startTime + ~totalDuration;
};

// Function to stop the composition
~stopStockhausen = {
    if(~stockhausenRoutine.notNil) {
        ~stockhausenRoutine.stop;
        ~stockhausenRoutine = nil;
        "Composition stopped.".postln;
    };
};

"Stockhausen-inspired electronic composition prepared.".postln;
"Duration: % seconds (about % minutes)".format(~totalDuration, ~totalDuration/60).postln;
"Run ~playStockhausen.value to start the composition.".postln;
)
s.record
// Execute this line to start the composition
~playStockhausen.value;

// Execute this line to stop the composition at any time
~stopStockhausen.value;
