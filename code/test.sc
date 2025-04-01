
// Initialize API with your key
~claude = ClaudeAPI("xxx");

// Ask a question and get just the text response
(
~claude.ask("Make a very basic Supercollider synth, send it to the server and create an instance of it and play using a = Synth(\nameOfSynth). Dont need to start the server of use s.sync",
  { |text|
    var sccode;
	// Success callback - this gets just the text string
    "Claude says:\n%".format(text).postln;
	// hack out the sc code part
	sccode = text.split($`)[3].replace("supercollider","");
	sccode.interpret;

},
  { |error|
    // Error callback
    "Error: %".format(error).postln;
  }
);
)

