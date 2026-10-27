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

// 5. patterns: the default pattern, then change it live
n.sendMsg('/ps/pattern/play', \perc);
n.sendMsg('/ps/pattern/set', \perc, \degree, 0, 2, 4, \r, 7, 4);
n.sendMsg('/ps/pattern/set', \perc, \scale, \dorian);
n.sendMsg('/ps/pattern/set', \perc, \dur, "Pwhite(0.1, 0.3)");
n.sendMsg('/ps/param/set', \perc, \decay, 1.2);      // bus param still applies to every note
n.sendMsg('/ps/tempo', 90);
n.sendMsg('/ps/pattern/stop', \perc);

// pad as a pattern, with a custom Pbind file
n.sendMsg('/ps/pattern/define', \pad, ~fx.("pattern.scd"));
n.sendMsg('/ps/pattern/play', \pad);
n.sendMsg('/ps/pattern/stop', \pad);

// 6. record 4 seconds while something plays -> library/pad/recordings/
n.sendMsg('/ps/pattern/play', \pad);
n.sendMsg('/ps/rec/start', \pad, 4);

// 7. state, panic
n.sendMsg('/ps/status');
n.sendMsg('/ps/panic');
