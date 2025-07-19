// Debug Test Suite for Anthropic.sc Class
(
var debugMode, testResults, log, assert;
var testClassInit, testApiKey, testUriGeneration, testJsonEncoding, testHeaders;
var testSimpleCompletion, testCodeGeneration, testChatMessages, testErrorHandling, testLegacyCompatibility;
var runAllTests, printTestSummary, quickTest;

// Test configuration
debugMode = true;
testResults = Dictionary.new;

log = { |msg, level="INFO"|
    if(debugMode) {
        ("[%] %".format(level, msg)).postln;
    };
};

assert = { |condition, testName|
    if(condition) {
        log.("PASS: " ++ testName, "PASS");
        testResults[testName] = true;
    } {
        log.("FAIL: " ++ testName, "FAIL");
        testResults[testName] = false;
    };
};

// Test 1: Class initialization
testClassInit = {
    log.("Testing Anthropic class initialization...");

    assert.(Anthropic.class.notNil, "Anthropic class exists");
    assert.(Anthropic.uris.notNil, "URIs initialized");
    assert.(Anthropic.uris[\BASE] == "https://api.anthropic.com/v1", "Base URI correct");
    assert.(Anthropic.model == "claude-3-5-sonnet-20241022", "Default model set");
    assert.(Anthropic.maxTokens == 1000, "Default max tokens set");
    assert.(Anthropic.temperature == 0.7, "Default temperature set");
};

// Test 2: API Key management
testApiKey = {
    var originalKey;

    log.("Testing API key management...");

    // Store original key if exists
    originalKey = Anthropic.apiKey;

    // Test key loading
    Anthropic.loadApiKey;
    assert.(Anthropic.apiKey.notNil, "API key loaded");
    assert.(Anthropic.apiKey.size > 10, "API key has reasonable length");

    // Test key setting
    Anthropic.apiKey = "test-key-123";
    assert.(Anthropic.apiKey == "test-key-123", "API key setting works");

    // Restore original key
    if(originalKey.notNil) {
        Anthropic.apiKey = originalKey;
    };
};

// Test 3: URI generation
testUriGeneration = {
    var messagesUri, completeUri;

    log.("Testing URI generation...");

    messagesUri = Anthropic.uri(\MESSAGES);
    completeUri = Anthropic.uri(\COMPLETE);

    assert.(messagesUri == "https://api.anthropic.com/v1/messages", "Messages URI correct");
    assert.(completeUri == "https://api.anthropic.com/v1/complete", "Complete URI correct");
};

// Test 4: JSON encoding
testJsonEncoding = {
    var testString, testNumber, testArray, testDict;
    var encodedString, encodedNumber, encodedArray, encodedDict;

    log.("Testing JSON encoding...");

    testString = "Hello \"world\"";
    testNumber = 42;
    testArray = ["a", "b", 1, 2];
    testDict = ("key1": "value1", "key2": 123);

    encodedString = AnthropicReq.basicJSON(testString);
    encodedNumber = AnthropicReq.basicJSON(testNumber);
    encodedArray = AnthropicReq.basicJSON(testArray);
    encodedDict = AnthropicReq.basicJSON(testDict);

    assert.(encodedString.includes("Hello \\\"world\\\""), "String encoding handles quotes");
    assert.(encodedNumber == "42", "Number encoding works");
    assert.(encodedArray.beginsWith("["), "Array encoding starts with bracket");
    assert.(encodedDict.beginsWith("{"), "Dictionary encoding starts with brace");
};

// Test 5: Request headers
testHeaders = {
    var headers;

    log.("Testing request headers...");

    headers = AnthropicReq.getHeaders;

    assert.(headers.isArray, "Headers is array");
    assert.(headers.any({|h| h.includes("Content-Type")}), "Content-Type header present");
    assert.(headers.any({|h| h.includes("x-api-key")}), "API key header present");
    assert.(headers.any({|h| h.includes("anthropic-version")}), "Version header present");
};

// Test 6: Simple completion (dry run)
testSimpleCompletion = {
    var testPrompt, testAction;

    log.("Testing simple completion structure...");

    testPrompt = "What is 2+2?";
    testAction = { |response|
        log.("Received response: " ++ response.class);
        assert.(response.notNil, "Response not nil");

        if(response.hasError) {
            log.("API Error: " ++ response.errorMessage, "WARN");
        } {
            log.("Response text: " ++ response.getText[0..100] ++ "...");
            assert.(response.getText.size > 0, "Response has text");
        };
    };

    // Note: This will make an actual API call
    log.("Making API call for simple completion test...");
    AnthropicMessage.simpleCompletion(testPrompt, action: testAction);
};

// Test 7: Code generation (dry run)
testCodeGeneration = {
    var testPrompt, testAction;

    log.("Testing code generation structure...");

    testPrompt = "A simple sine wave";
    testAction = { |response|
        var codeBlocks;

        log.("Code generation response: " ++ response.class);
        assert.(response.notNil, "Code response not nil");

        if(response.hasError) {
            log.("Code API Error: " ++ response.errorMessage, "WARN");
        } {
            codeBlocks = response.getCodeBlocks("supercollider");
            log.("Found % code blocks".format(codeBlocks.size));
            assert.(response.getText.size > 0, "Code response has text");
        };
    };

    log.("Making API call for code generation test...");
    AnthropicMessage.codeGeneration(testPrompt, "supercollider", testAction);
};

// Test 8: Chat messages
testChatMessages = {
    var messages, testAction;

    log.("Testing chat messages structure...");

    messages = [
        ("role": "user", "content": "Hello"),
        ("role": "assistant", "content": "Hi there!"),
        ("role": "user", "content": "How are you?")
    ];

    testAction = { |response|
        log.("Chat response: " ++ response.class);
        assert.(response.notNil, "Chat response not nil");

        if(response.hasError) {
            log.("Chat API Error: " ++ response.errorMessage, "WARN");
        } {
            log.("Chat response text: " ++ response.getText[0..50] ++ "...");
            assert.(response.getText.size > 0, "Chat response has text");
        };
    };

    log.("Making API call for chat test...");
    AnthropicMessage.create(messages, "You are a helpful assistant", action: testAction);
};

// Test 9: Error handling
testErrorHandling = {
    var originalKey, errorAction;

    log.("Testing error handling...");

    // Store original key
    originalKey = Anthropic.apiKey;

    // Set invalid key
    Anthropic.apiKey = "invalid-key-test";

    errorAction = { |response|
        log.("Error test response: " ++ response.class);
        assert.(response.notNil, "Error response not nil");
        assert.(response.hasError, "Response correctly identifies error");

        if(response.hasError) {
            log.("Expected error message: " ++ response.errorMessage);
        };

        // Restore original key
        Anthropic.apiKey = originalKey;
    };

    log.("Making API call with invalid key...");
    AnthropicMessage.simpleCompletion("Test", action: errorAction);
};

// Test 10: Legacy compatibility
testLegacyCompatibility = {
    var legacyAction;

    log.("Testing legacy compatibility...");

    legacyAction = { |result|
        log.("Legacy response: " ++ result.class);
        assert.(result.notNil, "Legacy response not nil");
        assert.(result.includesKey("completion") or: {result.includesKey("error")}, "Legacy format correct");

        if(result.includesKey("error")) {
            log.("Legacy error: " ++ result["error"]);
        } {
            log.("Legacy completion: " ++ result["completion"][0..50] ++ "...");
        };
    };

    log.("Making legacy API call...");
    AnthropicLegacy.makeApiCall("What is the weather like?", 50, legacyAction);
};

// Main test runner
runAllTests = {
    log.("=== Starting Anthropic Debug Tests ===");

    // Reset test results
    testResults = Dictionary.new;

    // Run tests
    testClassInit.();
    testApiKey.();
    testUriGeneration.();
    testJsonEncoding.();
    testHeaders.();

    // Wait a bit between API tests
    fork {
        2.wait;
        testSimpleCompletion.();

        3.wait;
        testCodeGeneration.();

        3.wait;
        testChatMessages.();

        3.wait;
        testErrorHandling.();

        3.wait;
        testLegacyCompatibility.();

        // Print summary after all tests
        3.wait;
        printTestSummary.();
    };
};

// Test summary
printTestSummary = {
    var total, passed, failed;

    log.("=== Test Summary ===");

    total = testResults.size;
    passed = testResults.values.count(true);
    failed = total - passed;

    log.("Total tests: " ++ total);
    log.("Passed: " ++ passed);
    log.("Failed: " ++ failed);

    if(failed > 0) {
        log.("Failed tests:");
        testResults.keysValuesDo({ |key, value|
            if(value == false) {
                log.("  - " ++ key, "FAIL");
            };
        });
    };

    log.("Success rate: " ++ (passed / total * 100).round(0.1) ++ "%");
    log.("=== Tests Complete ===");
};

// Quick individual test runners
quickTest = { |testName|
    switch(testName,
        "init", { testClassInit.() },
        "key", { testApiKey.() },
        "uri", { testUriGeneration.() },
        "json", { testJsonEncoding.() },
        "headers", { testHeaders.() },
        "simple", { testSimpleCompletion.() },
        "code", { testCodeGeneration.() },
        "chat", { testChatMessages.() },
        "error", { testErrorHandling.() },
        "legacy", { testLegacyCompatibility.() },
        {
            log.("Unknown test: " ++ testName, "ERROR");
            log.("Available: init, key, uri, json, headers, simple, code, chat, error, legacy");
        }
    );
};

log.("Anthropic debug test suite loaded!");
log.("Run runAllTests.() for all tests");
log.("Run quickTest.(\"testname\") for individual tests");
log.("Toggle debug: debugMode = false");
runAllTests.() ;
)