// ClaudeAPI examples: evaluate each block with Cmd-Enter, in order.
// Replies print in the post window after a few seconds.

// 1. text back
(
c = ClaudeAPI.new;
c.ask("say pong", { |t| t.postln }, { |e| ("FAIL: " ++ e).postln });
)

// 2. prompt into sound
s.boot;

(
c.ask("One line of SuperCollider: Ndef(\\synth, {...}).play, a gentle stereo drone around -12 dB. Code only, no code fences, no explanation.",
	{ |t| t.postln; t.interpret },
	{ |e| ("FAIL: " ++ e).postln });
)

Ndef(\synth).stop;

// 3. change values once it's written: ask for named args, so they become controls you can set
(
c.ask("One line of SuperCollider: Ndef(\\synth, {|freq=110, cutoff=1200, amp=0.2, rate=0.2| ...}).play, a stereo pad that uses all four args (rate = modulation speed). Code only, no code fences, no explanation.",
	{ |t| t.postln; t.interpret },
	{ |e| ("FAIL: " ++ e).postln });
)

Ndef(\synth).controlKeys.postln;     // the args you can set

Ndef(\synth).set(\freq, 55);
Ndef(\synth).set(\cutoff, 400, \rate, 2);
Ndef(\synth).set(\freq, 82.4, \cutoff, 3000, \amp, 0.1);
Ndef(\synth).xset(\freq, 165);      // crossfade to the new value (over Ndef(\synth).fadeTime)

Ndef(\synth).stop;
