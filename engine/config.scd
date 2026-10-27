// Engine settings. PS_LIBRARY_DIR and PS_OUT_DEVICE environment variables override.
(
	libraryDir: nil,          // nil = <repo>/library
	outDevice: nil,           // nil = system default, e.g. "MacBook Pro Speakers"
	inDevice: nil,
	numInputs: 0,             // > 0 enables SoundIn (macOS will ask for microphone access)
	sampleRate: nil,          // nil = device default
	memSize: 2 ** 16,         // KB of real-time memory, generated code loves delays and reverbs
	numWireBufs: 256,         // room for big generated graphs
	masterCeilingDb: -1,      // limiter ceiling on the master output
	masterAmp: 1,
	smokeDur: 2,              // seconds of audio analysed for each new synth
	releaseTimeout: 5,        // seconds a released synth gets to free itself
	recHeaderFormat: "wav",
	recSampleFormat: "int24",
	tempo: 120
)
