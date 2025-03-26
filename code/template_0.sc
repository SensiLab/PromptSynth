Ndef(\synth).source = {|note=42|
	SinOsc.ar([note.midicps, note.midicps*1.004], 0, 0.5)
})


