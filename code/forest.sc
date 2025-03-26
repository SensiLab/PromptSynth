(
SynthDef(\forestBreeze, {
    arg out=0,
    // Breeze controls
    breezeAmp=0.3, breezeCutoff=400, breezeQ=0.5, breezeSpeed=0.2, breezePan=0,
    // Leaves controls
    leavesAmp=0.2, leavesDensity=1.0, leavesBrightness=3000, leavesPan=0,
    // Tree controls
    treeAmp=0.15, treeResonance=100, treeSpeed=0.1, treePan=0,
    // Reverb controls for each element
    breezeVerb=0.3, leavesVerb=0.4, treeVerb=0.5,
    // Master controls
    masterAmp=1.0, gate=1;

    var breeze, leaves, trees, mainEnv;
    var breezeVerbed, leavesVerbed, treesVerbed;

    // Main envelope
    mainEnv = EnvGen.kr(
        Env.asr(3, 1, 3),
        gate,
        doneAction: 2
    );

    //------ Breeze Component ------//
    breeze = {
        var base, filtered, modulated;
        // Base noise with smooth fluctuation
        base = PinkNoise.ar * LFNoise2.kr(breezeSpeed).range(0.7, 1.0);

        // Multi-filtered noise for wind character
        filtered = RLPF.ar(
            base,
            LFNoise2.kr(breezeSpeed * 0.5).range(breezeCutoff * 0.7, breezeCutoff * 1.3),
            breezeQ
        );

        // Additional modulation layer
        modulated = filtered * LFNoise2.kr(
            breezeSpeed * 0.7,
            mul: 0.3,
            add: 0.7
        );

        Pan2.ar(modulated * breezeAmp, breezePan)
    }.();

    //------ Leaves Component ------//
    leaves = {
        var base, filtered, crackles;
        // Base texture
        base = BrownNoise.ar * leavesDensity;

        // High frequency content for leaf detail
        filtered = HPF.ar(base, leavesBrightness);

        // Add subtle crackles
        crackles = Dust2.ar(
            LFNoise2.kr(0.4).range(20, 50) * leavesDensity
        );

        // Combine and shape
        filtered = ((filtered * 0.7) + (crackles * 0.3)) *
        LFNoise2.kr(
            LFNoise2.kr(0.1).range(0.3, 0.7)
        ).range(0.5, 1.0);

        Pan2.ar(filtered * leavesAmp, leavesPan)
    }.();

    //------ Trees Component ------//
    trees = {
        var base, resonant, modulated;
        // Low frequency movement
        base = LFNoise2.ar(
            LFNoise2.kr(0.05).range(0.2, 0.4) * treeSpeed
        );

        // Resonant filter for wooden creaking
        resonant = Resonz.ar(
            base,
            LFNoise2.kr(treeSpeed * 0.3).range(treeResonance * 0.8, treeResonance * 1.2),
            0.1
        );

        // Add occasional creaks
        modulated = resonant + (
            Dust2.ar(0.5) *
            SinOsc.ar(
                LFNoise2.kr(0.1).range(treeResonance * 0.7, treeResonance * 1.1)
            ) * 0.1
        );

        Pan2.ar(modulated * treeAmp, treePan)
    }.();

    // Apply individual reverbs
    breezeVerbed = FreeVerb2.ar(
        breeze[0], breeze[1],
        mix: breezeVerb,
        room: 0.8,
        damp: 0.2
    );

    leavesVerbed = FreeVerb2.ar(
        leaves[0], leaves[1],
        mix: leavesVerb,
        room: 0.6,
        damp: 0.4
    );

    treesVerbed = FreeVerb2.ar(
        trees[0], trees[1],
        mix: treeVerb,
        room: 0.9,
        damp: 0.2
    );

    // Final mix and output
    Out.ar(out,
        (breezeVerbed + leavesVerbed + treesVerbed) *
        mainEnv *
        masterAmp
    );
}).add;

// Example pattern with subtle movement
Pbindef(\forestScene,
    \instrument, \forestBreeze,
    \dur, 12, // Overlap for continuity
    \masterAmp, 1.0,

    // Breeze variations
    \breezeAmp, Pwhite(0.25, 0.35),
    \breezeCutoff, Pseg(Pseq([300, 600, 300], inf), 30, \sin),
    \breezeSpeed, Pwhite(0.15, 0.25),
    \breezePan, Pseg(Pseq([-0.3, 0.3, -0.3], inf), 20, \sin),

    // Leaves variations
    \leavesAmp, Pwhite(0.15, 0.25),
    \leavesDensity, Pseg(Pseq([0.8, 1.2, 0.8], inf), 25, \sin),
    \leavesPan, Pseg(Pseq([0.3, -0.3, 0.3], inf), 15, \sin),

    // Tree variations
    \treeAmp, Pwhite(0.1, 0.2),
    \treeSpeed, Pwhite(0.08, 0.12),
    \treePan, Pseg(Pseq([-0.2, 0.2, -0.2], inf), 30, \sin),

    // Individual reverbs
    \breezeVerb, 0.3,
    \leavesVerb, 0.4,
    \treeVerb, 0.5
);
)

// Start the soundscape:
Pbindef(\forestScene).play;

// Stop:
Pbindef(\forestScene).stop;
(
// Or create a single instance with specific settings:
~forest = Synth(\forestBreeze, [
    \breezeAmp, 0.2,
    \leavesAmp, 0.3,
    \treeAmp, 0.35,
    \breezeCutoff, 500,
    \leavesDensity, 0.9,
    \treeSpeed, 0.1
]);
)

// Free it:
~forest.free;
