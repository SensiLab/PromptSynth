// Simple API test for generating SynthDef code
(
var generateSynthDef;

generateSynthDef = {
    var prompt;
    
    prompt = "Generate a SuperCollider SynthDef that creates an ambient drone sound. Use SinOsc, filters, and slow modulation. Format as: SynthDef(\\drone, { ... }).add;";
    
    Anthropic.generateCode(prompt, "supercollider", { |response|
        if(response.hasError) {
            ("Error: " ++ response.errorMessage).postln;
        } {
            "Generated SynthDef:".postln;
            response.getText.postln;
        };
    });
};

"Simple SynthDef generator loaded.".postln;
"Run: generateSynthDef.()".postln;
)