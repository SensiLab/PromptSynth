// Xenakis-inspired Electronic Composition
// Showcasing techniques including:
// - Stochastic processes
// - Granular synthesis
// - Probability distributions
// - Glissandi clouds
// - Mathematical structures

// Boot the server
s.boot;

// Set overall volume
s.volume = -3;

(
// PART 1: SYNTH DEFINITIONS

// Granular synthesis synth (inspired by Xenakis's granular techniques in Concret PH)
SynthDef(\xenakisGrain, {
    |out=0, freq=1000, amp=0.3, pan=0, attack=0.001, sustain=0.01, release=0.01, density=50, deviation=0.2|

    var sig, env, grainEnv, trig;

    // Grain trigger with random timing
    trig = Dust.ar(density);

    // Grain envelope
    grainEnv = EnvGen.ar(
        Env.perc(attack, release, 1, -4),
        trig
    );

    // Random frequency deviation for each grain
    freq = freq * LFNoise1.ar(density).range(1-deviation, 1+deviation);

    // Simple sine oscillator for each grain
    sig = SinOsc.ar(freq) * grainEnv;

    // Apply global envelope
    env = EnvGen.kr(Env.linen(0.01, sustain, 0.01), doneAction: 2);

    // Output with level control and spatialization
    sig = sig * env * amp;
    sig = Pan2.ar(sig, pan);

    Out.ar(out, sig);
}).add;

// Stochastic synthesis (inspired by GENDY and Dynamic Stochastic Synthesis)
SynthDef(\xenakisStochastic, {
    |out=0, freq=440, amp=0.3, pan=0, attack=0.01, sustain=0.1, release=0.1,
    complexity=10, deviation=0.5, rate=10|

    var sig, env, osc;

    // Stochastic oscillator (approximation of Xenakis's GENDY)
    osc = LFNoise2.ar(rate).range(-1, 1);

    // Apply complexity by layering different rates of noise
    complexity.do { |i|
        var factor = i + 1;
        osc = osc + (LFNoise2.ar(rate * factor * 0.5) * (1/factor));
    };
    osc = osc * 0.3; // Scale to prevent clipping

    // Apply frequency
    sig = osc * freq * deviation;

    // Apply global envelope
    env = EnvGen.kr(Env.linen(attack, sustain, release), doneAction: 2);

    // Output with level control and spatialization
    sig = sig * env * amp;
    sig = Pan2.ar(sig, pan);

    Out.ar(out, sig);
}).add;

// Glissandi synth (inspired by Metastasis and other glissandi works)
SynthDef(\xenakisGlissando, {
    |out=0, startFreq=1000, endFreq=500, amp=0.3, pan=0, attack=0.01, sustain=0.1, release=0.1|

    var sig, env, freqEnv;

    // Frequency envelope for glissando
    freqEnv = EnvGen.ar(Env.new([startFreq, endFreq], [sustain], \lin));

    // Oscillator with glissando
    sig = SinOsc.ar(freqEnv);

    // Apply global envelope
    env = EnvGen.kr(Env.linen(attack, sustain, release), doneAction: 2);

    // Output with level control and spatialization
    sig = sig * env * amp;
    sig = Pan2.ar(sig, pan);

    Out.ar(out, sig);
}).add;

// Stochastic resonant noise (inspired by Concret PH and Bohor)
SynthDef(\xenakisNoise, {
    |out=0, amp=0.3, pan=0, attack=0.01, sustain=0.1, release=0.1,
    freq=1000, rq=0.5, density=20|

    var sig, env, filt;

    // Filtered noise with stochastic modulation
    sig = WhiteNoise.ar();

    // Stochastic filter frequency modulation
    freq = freq * LFNoise2.kr(density).range(0.5, 2);

    // Apply resonant filter
    filt = BPF.ar(sig, freq, rq);

    // Apply global envelope
    env = EnvGen.kr(Env.linen(attack, sustain, release), doneAction: 2);

    // Output with level control and spatialization
    sig = filt * env * amp;
    sig = Pan2.ar(sig, pan);

    Out.ar(out, sig);
}).add;
)
s.sync; // Wait for synths to be added

// PART 2: COMPOSITION USING STOCHASTIC PROCESSES

(
// Xenakis often used formal mathematics to organize his compositions
// We'll implement stochastic distributions and sieve-based structures

// Create mathematical tools first
// Sieve generation (inspired by Xenakis's sieve theory)
~sieve = { |modulo, residues, length|
    var result = Array.newClear(length);
    length.do { |i|
        residues.do { |res|
            if(i % modulo == res) { result[i] = 1 };
        };
    };
    result.collect { |val| if(val.isNil) { 0 } { val } };
};

// Random walk with bounds (for glissandi organizations)
~randomWalk = { |start, steps, step_size, min, max|
    var result = Array.newClear(steps + 1);
    result[0] = start;
    steps.do { |i|
        var next = result[i] + (step_size * (2.0.rand - 1));
        result[i+1] = next.clip(min, max);
    };
    result;
};

// Exponential distribution (Xenakis used various distributions)
~expRand = { |min, max|
    min * ((max/min) ** 1.0.rand);
};

// Create the timing structure for the piece
// Xenakis often divided pieces into sections with different characteristics

// Total duration in seconds
~totalDuration = 120; // 2 minutes

// Define sections using Fibonacci-related durations (Xenakis used these regularly)
~sectionDurations = [13, 21, 8, 13, 34, 21, 13]; // Fibonacci-adjacent values
~sectionDurations = ~sectionDurations * (~totalDuration / ~sectionDurations.sum); // Scale to total duration

// Event organization using sieves
~section1Rhythm = ~sieve.(5, [0, 1, 3], 40); // Rhythmic pattern from a sieve
~section1Density = ~section1Rhythm.sum; // Number of events in section 1

// Create event arrays to hold all generated events
~events = List.new; // Will store all events

// SECTION 1: Granular clouds (inspired by Concret PH)
~currentTime = 0;

~section1Rhythm.do { |trigger, i|
    if(trigger == 1) {
        var event = Dictionary.new;
        var duration = ~expRand.(0.2, 2.0); // Exponentially distributed durations

        event.put(\time, ~currentTime + (i * ~sectionDurations[0] / 40));
        event.put(\synth, \xenakisGrain);
        event.put(\freq, ~expRand.(1000, 8000)); // Exponential distribution for frequencies
        event.put(\density, ~expRand.(20, 200)); // Grains per second
        event.put(\deviation, 0.3.rrand(0.7));
        event.put(\sustain, duration);
        event.put(\amp, ~expRand.(0.1, 0.3));
        event.put(\pan, 1.0.rand2); // Random panning

        ~events.add(event);
    };
};

// SECTION 2: Stochastic glissandi (inspired by Metastasis)
~currentTime = ~sectionDurations[0];

// Generate clusters of glissandi
~numGlissandi = 15;
~numGlissandi.do { |i|
    var event = Dictionary.new;
    var startFreq = ~expRand.(500, 3000);
    var endFreq = ~expRand.(500, 3000);
    var duration = ~expRand.(0.5, 4.0);

    event.put(\time, ~currentTime + (~sectionDurations[1] * i / ~numGlissandi));
    event.put(\synth, \xenakisGlissando);
    event.put(\startFreq, startFreq);
    event.put(\endFreq, endFreq);
    event.put(\sustain, duration);
    event.put(\attack, 0.05);
    event.put(\release, 0.05);
    event.put(\amp, ~expRand.(0.1, 0.2));
    event.put(\pan, 1.0.rand2);

    ~events.add(event);
};

// SECTION 3: Stochastic synthesis (inspired by GENDY)
~currentTime = ~sectionDurations[0] + ~sectionDurations[1];

// Generate stochastic synthesis events
~numStochEvents = 10;
~numStochEvents.do { |i|
    var event = Dictionary.new;
    var duration = ~expRand.(0.2, 1.5);

    event.put(\time, ~currentTime + (~sectionDurations[2] * i / ~numStochEvents));
    event.put(\synth, \xenakisStochastic);
    event.put(\freq, ~expRand.(100, 800));
    event.put(\complexity, 5.rrand(15));
    event.put(\rate, ~expRand.(5, 30));
    event.put(\deviation, 0.2.rrand(0.8));
    event.put(\sustain, duration);
    event.put(\amp, ~expRand.(0.15, 0.25));
    event.put(\pan, 1.0.rand2);

    ~events.add(event);
};

// SECTION 4: Dense granular clouds with varying density
~currentTime = ~sectionDurations[0] + ~sectionDurations[1] + ~sectionDurations[2];

// Generate dense granular textures
~numGranTextures = 8;
~numGranTextures.do { |i|
    var event = Dictionary.new;
    var duration = ~expRand.(1.0, 3.0);

    event.put(\time, ~currentTime + (~sectionDurations[3] * i / ~numGranTextures));
    event.put(\synth, \xenakisGrain);
    event.put(\freq, ~expRand.(200, 2000));
    event.put(\density, ~expRand.(100, 500)); // Higher density
    event.put(\deviation, 0.5.rrand(0.9)); // More variation
    event.put(\sustain, duration);
    event.put(\amp, ~expRand.(0.1, 0.25));
    event.put(\pan, 1.0.rand2);

    ~events.add(event);
};

// SECTION 5: Stochastic noise textures (inspired by Bohor)
~currentTime = ~sectionDurations[0] + ~sectionDurations[1] + ~sectionDurations[2] + ~sectionDurations[3];

// Generate noise events with stochastic organization
~noisePattern = ~sieve.(7, [0, 1, 2, 4], 30); // Different sieve pattern
~noisePattern.do { |trigger, i|
    if(trigger == 1) {
        var event = Dictionary.new;
        var duration = ~expRand.(0.5, 3.0);

        event.put(\time, ~currentTime + (i * ~sectionDurations[4] / 30));
        event.put(\synth, \xenakisNoise);
        event.put(\freq, ~expRand.(500, 5000));
        event.put(\rq, ~expRand.(0.05, 0.5)); // Sharp to medium resonances
        event.put(\density, ~expRand.(5, 40));
        event.put(\sustain, duration);
        event.put(\attack, 0.05);
        event.put(\release, 0.1);
        event.put(\amp, ~expRand.(0.15, 0.35));
        event.put(\pan, 1.0.rand2);

        ~events.add(event);
    };
};

// SECTION 6: Dense stochastic synthesis (climax section)
~currentTime = ~sectionDurations[0] + ~sectionDurations[1] + ~sectionDurations[2] +
               ~sectionDurations[3] + ~sectionDurations[4];

// Generate multiple overlapping stochastic synthesis events
~numDenseStoch = 20;
~numDenseStoch.do { |i|
    var event = Dictionary.new;
    var duration = ~expRand.(0.3, 2.0);

    event.put(\time, ~currentTime + (~sectionDurations[5] * i / ~numDenseStoch));
    event.put(\synth, \xenakisStochastic);
    event.put(\freq, ~expRand.(50, 1200));
    event.put(\complexity, 8.rrand(20)); // Higher complexity
    event.put(\rate, ~expRand.(10, 50)); // Faster rate
    event.put(\deviation, 0.4.rrand(1.0)); // More extreme
    event.put(\sustain, duration);
    event.put(\amp, ~expRand.(0.1, 0.2)); // Lower to avoid overload
    event.put(\pan, 1.0.rand2);

    ~events.add(event);
};

// SECTION 7: Sparse ending with isolated events (following Xenakis's often abrupt endings)
~currentTime = ~sectionDurations[0] + ~sectionDurations[1] + ~sectionDurations[2] +
               ~sectionDurations[3] + ~sectionDurations[4] + ~sectionDurations[5];

// Final sparse events
5.do { |i|
    var event = Dictionary.new;
    var duration = ~expRand.(0.1, 0.5);
    var which = 4.rand;

    event.put(\time, ~currentTime + (~sectionDurations[6] * i / 5));

    switch(which,
        0, {
            event.put(\synth, \xenakisGrain);
            event.put(\freq, ~expRand.(2000, 8000));
            event.put(\density, ~expRand.(20, 100));
            event.put(\deviation, 0.3.rrand(0.7));
        },
        1, {
            event.put(\synth, \xenakisStochastic);
            event.put(\freq, ~expRand.(100, 500));
            event.put(\complexity, 3.rrand(8));
            event.put(\rate, ~expRand.(5, 20));
            event.put(\deviation, 0.2.rrand(0.5));
        },
        2, {
            event.put(\synth, \xenakisGlissando);
            event.put(\startFreq, ~expRand.(1000, 4000));
            event.put(\endFreq, ~expRand.(200, 1000));
        },
        3, {
            event.put(\synth, \xenakisNoise);
            event.put(\freq, ~expRand.(1000, 3000));
            event.put(\rq, ~expRand.(0.05, 0.2));
            event.put(\density, ~expRand.(5, 20));
        }
    );

    event.put(\sustain, duration);
    event.put(\amp, ~expRand.(0.1, 0.3));
    event.put(\pan, 1.0.rand2);

    ~events.add(event);
};

// Sort all events by time
~events = ~events.sort({ |a, b| a[\time] < b[\time] });

// Function to play the Xenakis composition
~playXenakis = {
    var startTime = Main.elapsedTime;

    // Create a routine to play all events
    ~xenakisRoutine = Routine({
        var lastTime = 0;

        ~events.do { |event, i|
            var timeToWait = event[\time] - lastTime;
            timeToWait.wait;
            lastTime = event[\time];

            // Play the event based on its type
            switch(event[\synth],
                \xenakisGrain, {
                    Synth(\xenakisGrain, [
                        \freq, event[\freq],
                        \amp, event[\amp],
                        \pan, event[\pan],
                        \attack, 0.001,
                        \sustain, event[\sustain],
                        \release, 0.001,
                        \density, event[\density],
                        \deviation, event[\deviation]
                    ]);
                    "Event %: Grain at % sec, freq: %, density: %".format(
                        i, event[\time].round(0.01), event[\freq].round(0.1), event[\density].round(0.1)
                    ).postln;
                },
                \xenakisStochastic, {
                    Synth(\xenakisStochastic, [
                        \freq, event[\freq],
                        \amp, event[\amp],
                        \pan, event[\pan],
                        \attack, 0.01,
                        \sustain, event[\sustain],
                        \release, 0.05,
                        \complexity, event[\complexity],
                        \deviation, event[\deviation],
                        \rate, event[\rate]
                    ]);
                    "Event %: Stochastic at % sec, freq: %, complexity: %".format(
                        i, event[\time].round(0.01), event[\freq].round(0.1), event[\complexity]
                    ).postln;
                },
                \xenakisGlissando, {
                    Synth(\xenakisGlissando, [
                        \startFreq, event[\startFreq],
                        \endFreq, event[\endFreq],
                        \amp, event[\amp],
                        \pan, event[\pan],
                        \attack, event[\attack] ?? 0.01,
                        \sustain, event[\sustain],
                        \release, event[\release] ?? 0.05
                    ]);
                    "Event %: Glissando at % sec, %Hz to %Hz".format(
                        i, event[\time].round(0.01), event[\startFreq].round(0.1), event[\endFreq].round(0.1)
                    ).postln;
                },
                \xenakisNoise, {
                    Synth(\xenakisNoise, [
                        \amp, event[\amp],
                        \pan, event[\pan],
                        \attack, event[\attack] ?? 0.01,
                        \sustain, event[\sustain],
                        \release, event[\release] ?? 0.05,
                        \freq, event[\freq],
                        \rq, event[\rq],
                        \density, event[\density]
                    ]);
                    "Event %: Noise at % sec, freq: %Hz, Q: %".format(
                        i, event[\time].round(0.01), event[\freq].round(0.1), event[\rq].round(0.01)
                    ).postln;
                }
            );
        };

        // Wait until the end of the piece
        (~totalDuration - lastTime).wait;
        "Xenakis composition complete.".postln;
    });

    // Start the routine
    ~xenakisRoutine.play;

    // Return the end time for reference
    startTime + ~totalDuration;
};

// Function to stop the composition
~stopXenakis = {
    if(~xenakisRoutine.notNil) {
        ~xenakisRoutine.stop;
        ~xenakisRoutine = nil;
        "Composition stopped.".postln;
    };
};

"Xenakis-inspired electronic composition prepared.".postln;
"Duration: % seconds (about % minutes)".format(~totalDuration, ~totalDuration/60).postln;
"Run ~playXenakis.value to start the composition.".postln;
)
s.record
// Execute this line to start the composition
~playXenakis.value;

// Execute this line to stop the composition at any time
~stopXenakis.value;