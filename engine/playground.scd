// PromptSynth engine playground. Open in the SC IDE and evaluate step by step (Cmd-Enter).
// Everything goes over OSC, exactly like the daemon / web UI / other controllers will.

// 1. start the engine (boots the server, loads library/), wait for "[ps] ready"
(thisProcess.nowExecutingPath.dirname +/+ "main.scd").load;

// 2. an address to talk to it, and print every result and event
(
~fx = { |file| thisProcess.nowExecutingPath.dirname +/+ "test/fixtures" +/+ file };
n = NetAddr("127.0.0.1", NetAddr.langPort);
OSCdef(\psResult, { |msg| ("RESULT " ++ msg[1] ++ " " ++ msg[2]).postln }, '/ps/result');
OSCdef(\psEvent, { |msg| ("event " ++ msg).postln }, '/ps/event/synth');
n.sendMsg('/ps/subscribe');
n.sendMsg('/ps/master/amp', 0.5); // start gentle
)

// 3. define synths: watch the RESULT line (kind, params, peakDb, warnings)
n.sendMsg('/ps/synth/define', \pad, ~fx.("pad_v2.scd"), "{\"prompt\": \"playground test\"}");
n.sendMsg('/ps/synth/define', \texture, ~fx.("texture.scd"));
n.sendMsg('/ps/synth/define', \perc, ~fx.("perc.scd"));

// ...and some that fail, to see the errors Claude will get
n.sendMsg('/ps/synth/define', \oops, ~fx.("fixed_bus.scd"));
n.sendMsg('/ps/synth/define', \oops, ~fx.("nan.scd"));

// 4. single instance + params
n.sendMsg('/ps/synth/play', \pad);
n.sendMsg('/ps/param/set', \pad, \cutoff, 400);
n.sendMsg('/ps/param/norm', \pad, \cutoff, 0.9);   // 0..1 like a fader
n.sendMsg('/ps/param/set', \pad, \detune, 0.04);
n.sendMsg('/ps/param/get', \pad);
n.sendMsg('/ps/synth/release', \pad);

// sweep a param from a "controller"
(
fork {
	50.do { |i| n.sendMsg('/ps/param/norm', \pad, \cutoff, sin(i / 50 * pi)); 0.05.wait };
};
n.sendMsg('/ps/synth/play', \pad);
)

// texture (a plain function, auto-wrapped)
n.sendMsg('/ps/synth/play', \texture);
n.sendMsg('/ps/param/set', \texture, \note, 47);
n.sendMsg('/ps/synth/release', \texture);

// one-shot: each play triggers a new note
n.sendMsg('/ps/synth/play', \perc);

// 5. patterns are named and bound to a synth: a quick default pattern, changed live
n.sendMsg('/ps/pattern/default', \percs, \perc);
n.sendMsg('/ps/pattern/play', \percs);
n.sendMsg('/ps/pattern/set', \percs, \degree, 0, 2, 4, \r, 7, 4);
n.sendMsg('/ps/pattern/set', \percs, \scale, \dorian);
n.sendMsg('/ps/pattern/set', \percs, \dur, "Pwhite(0.1, 0.3)");
n.sendMsg('/ps/param/set', \perc, \decay, 1.2);      // synth params still reach every note
n.sendMsg('/ps/tempo', 90);
n.sendMsg('/ps/pattern/play', \percs, \pad);           // same pattern, another synth
n.sendMsg('/ps/pattern/stop', \percs);

// a pattern from a file (saved to library/patterns/walk/), bound to pad
n.sendMsg('/ps/pattern/define', \walk, ~fx.("pattern.scd"), \pad);
n.sendMsg('/ps/pattern/play', \walk);
n.sendMsg('/ps/pattern/get', \walk);
n.sendMsg('/ps/pattern/stop', \walk);

// 6. control channels and mappings: synths never read the mouse; channels are mapped onto params
n.sendMsg('/ps/channel/list');
n.sendMsg('/ps/map', \pad, \cutoff, \mouseX);               // range and warp from the param's spec
n.sendMsg('/ps/map', \pad, \detune, \mouseY, 0, 0.05, \lin);
n.sendMsg('/ps/synth/play', \pad);                          // move the mouse
n.sendMsg('/ps/map', \pad, \amp, \key_space, 0.05, 0.4);    // louder while space is held
n.sendMsg('/ps/channel/set', \fader1, 0.5);                 // any other name is an OSC channel
n.sendMsg('/ps/map', \pad, \cutoff, \fader1);
n.sendMsg('/ps/unmap', \pad, \cutoff);
n.sendMsg('/ps/synth/release', \pad);

// 7. record 4 seconds while something plays -> library/patterns/walk/recordings/
n.sendMsg('/ps/pattern/play', \walk);
n.sendMsg('/ps/rec/start', \walk, 4);

// 8. state, panic
n.sendMsg('/ps/status');
n.sendMsg('/ps/panic');
