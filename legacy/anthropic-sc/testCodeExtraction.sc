// Test extracting code blocks from Anthropic response
(
var testCodeExtraction;

testCodeExtraction = {
    var prompt;
    
    prompt = "Generate a SuperCollider SynthDef for a bass drum sound. Include the code in a supercollider code block.";
    
    Anthropic.generateCode(prompt, "supercollider", { |response|
        var codeBlocks, extractedCode;
        
        if(response.hasError) {
            ("Error: " ++ response.errorMessage).postln;
        } {
            "Full response:".postln;
            response.getText.postln;
            "".postln;
            
            // Extract code blocks
            codeBlocks = response.getCodeBlocks("supercollider");
            
            if(codeBlocks.size > 0) {
                "Extracted code blocks (%):".format(codeBlocks.size).postln;
                codeBlocks.do({ |code, i|
                    ("Block %: %".format(i+1, code)).postln;
                    "".postln;
                });
                
                // Use first code block
                extractedCode = codeBlocks[0];
                "Executing first code block...".postln;
                try {
                    extractedCode.interpret;
                    "Code executed successfully!".postln;
                } {
                    |error|
                    ("Execution error: " ++ error.errorString).postln;
                };
            } {
                "No code blocks found in response".postln;
            };
        };
    });
};

"Code extraction test loaded.".postln;
"Run: testCodeExtraction.()".postln;
)