// ClaudeAPI - SuperCollider wrapper for Anthropic's Claude API
// Based on similar structure to FSSound (Freesound Quark)

// Configuration Manager Class
ClaudeConfig {
	classvar <apiKey, <apiUrl = "https://api.anthropic.com/v1";
	classvar <defaultModel = "claude-3-7-sonnet-20250219";
	classvar <defaultParams;

	*initClass {
		defaultParams = (
			\temperature: 0.7,
			\max_tokens: 4096,
			\top_p: 0.95,
			\top_k: 40
		);
	}

	*setApiKey { |key|
		apiKey = key;
	}

	*setApiUrl { |url|
		apiUrl = url;
	}

	*setDefaultModel { |model|
		defaultModel = model;
	}

	*setDefaultParam { |key, value|
		defaultParams[key] = value;
	}
}

// Request Handler Class
ClaudeReq {
	classvar <>timeout = 60;
	classvar <>retryAttempts = 3;
	classvar <>retryDelay = 2;

	*makeRequest { |endpoint, method="POST", data, onComplete, onFailure|
		var curl, cmd, tempFile, responseFile, headers;
		var attempt, tmpDir, doRequest;

		attempt = 0;

		// Get a guaranteed valid temporary directory
		tmpDir = Platform.userAppSupportDir +/+ "tmp";
		// Ensure the directory exists
		if(File.exists(tmpDir).not) {
			File.mkdir(tmpDir);
		};

		"ClaudeAPI: Using temp directory: %".format(tmpDir).postln;
		"ClaudeAPI: Making request to endpoint: %".format(endpoint).postln;

		if(ClaudeConfig.apiKey.isNil) {
			Error("ClaudeAPI: API key not set. Use ClaudeConfig.setApiKey first.").throw;
		};

		// Validate the data
		if(data.isNil || (data.isString && (data.size <= 5))) {
			Error("ClaudeAPI: Request data is missing or empty").throw;
		};

		// Create temporary files with full explicit paths
		tempFile = tmpDir +/+ "claudeRequestData" ++ Date.getDate.stamp ++ ".json";
		responseFile = tmpDir +/+ "claudeResponse" ++ Date.getDate.stamp ++ ".json";

		// Write request data to temp file
		"ClaudeAPI: Writing request data to temp file: %".format(tempFile).postln;
		File.use(tempFile, "w") { |f|
			"ClaudeAPI: Request data length: % characters".format(data.size).postln;
			f.write(data);
		};

		// Verify file was written correctly
		"ClaudeAPI: Verifying request data file...".postln;
		if(File.exists(tempFile)) {
			var fileSize = File.fileSize(tempFile);
			"ClaudeAPI: Request data file size: % bytes".format(fileSize).postln;
			if(fileSize <= 5) {
				"ClaudeAPI: WARNING - Request data file is empty or too small!".postln;
				Error("ClaudeAPI: Unable to write request data to file.").throw;
			};
		} {
			"ClaudeAPI: WARNING - Request data file does not exist!".postln;
			Error("ClaudeAPI: Unable to create request data file.").throw;
		};

		// Setup headers
		headers = [
			"Content-Type: application/json",
			"anthropic-version: 2023-06-01",
			"x-api-key: %".format(ClaudeConfig.apiKey)
		];

		// Start a forked process for handling the async request
		fork {
			// Create the curl command with additional options for reliability and verbose debugging
			curl = "curl -v -s -S --retry 3 --retry-delay 2 --connect-timeout 30 -X % '%/%' -H '%' -H '%' -H '%'".format(
				method,
				ClaudeConfig.apiUrl,
				endpoint,
				headers[0],
				headers[1],
				headers[2]
			);

			// Add data if present
			if(data.notNil) {
				curl = curl + " -d @'%'".format(tempFile);
			};

			// Add output file
			curl = curl + " -o '%'".format(responseFile);

			// Recursive retry function
			doRequest = { |currentAttempt|
				// Execute curl command with -v for verbose output to help debug
				"ClaudeAPI: Executing curl command (attempt %/%): %".format(currentAttempt + 1, retryAttempts, curl).postln;
				cmd = curl.unixCmd({ |exitCode|
					"ClaudeAPI: curl completed with exit code %".format(exitCode).postln;

					// Add specific error code explanations
					if(exitCode != 0) {
						switch(exitCode,
							26, { "ClaudeAPI: Error 26 - Read error (The server closed the connection or there was a network issue)".postln; },
							28, { "ClaudeAPI: Error 28 - Timeout".postln; },
							35, { "ClaudeAPI: Error 35 - SSL/TLS handshake issue".postln; },
							56, { "ClaudeAPI: Error 56 - Network failure".postln; },
							{ "ClaudeAPI: Unknown curl error: %".format(exitCode).postln; }
						);
					};

					fork {
						if(exitCode == 0) {
							// Read response
							if(File.exists(responseFile)) {
								var response, parsed, fileSize;

								response = File.use(responseFile, "r") { |f| f.readAllString };
								fileSize = File.fileSize(responseFile);
								"ClaudeAPI: Response file size: % bytes".format(fileSize).postln;

								try {
									"ClaudeAPI: Attempting to parse response: %".format(response.keep(100) ++ "...").postln;
									parsed = response.parseJSON;
									"ClaudeAPI: Successfully parsed response".postln;
									onComplete.value(parsed);
								} {
									"ClaudeAPI: Error parsing response".postln;
									if(currentAttempt < (retryAttempts - 1)) {
										"ClaudeAPI: Will retry in % seconds...".format(retryDelay).postln;
										retryDelay.wait;
										doRequest.value(currentAttempt + 1);
									} {
										onFailure.value("Failed to parse response: %".format(response));
									};
								};

								// Clean up temp files
								// File.delete(responseFile);
								// if(data.notNil) {
								// 	File.delete(tempFile);
								// };
							} {
								if(currentAttempt < (retryAttempts - 1)) {
									"ClaudeAPI: Response file not found. Will retry in % seconds...".format(retryDelay).postln;
									retryDelay.wait;
									doRequest.value(currentAttempt + 1);
								} {
									onFailure.value("Response file not created");
								};
							};
						} {
							if(currentAttempt < (retryAttempts - 1)) {
								"ClaudeAPI: Curl error (code %). Will retry in % seconds...".format(exitCode, retryDelay).postln;
								retryDelay.wait;
								doRequest.value(currentAttempt + 1);
							} {
								onFailure.value("Curl error with exit code %".format(exitCode));
							};
						};
					}; // End of fork
				});
			};

			// Start the request process with attempt 0
			doRequest.value(0);
		};

		^cmd;  // Return the unix command process
	}
}

// Response Parser Class
ClaudeResp {
	*parse { |response|
		var result, textParts;

		result = ();
		textParts = [];

		"ClaudeResp: Parsing response...".postln;
		"ClaudeResp: Raw response: %".format(response).postln;

		// Check if there's an error in the response
		if(response.isNil) {
			"ClaudeResp: Response is nil".postln;
			result[\isError] = true;
			result[\error] = "No response received";
			result[\errorType] = "empty_response";
			^result;
		};

		// Debug the full response structure
		"ClaudeResp: Response keys: %".format(response.keys).postln;

		// Check for error field anywhere in the response structure
		if(response['error'].notNil) {
			"ClaudeResp: Found error in response".postln;
			result[\isError] = true;

			if(response['error'].isKindOf(Dictionary) || response['error'].isKindOf(Event)) {
				result[\error] = response['error']['message'] ?? "Unknown error";
				result[\errorType] = response['error']['type'] ?? "unknown_error";
				result[\errorCode] = response['error']['status'] ?? 500;
			} {
				result[\error] = response['error'].asString;
				result[\errorType] = "unknown_error";
			};

			result[\raw] = response;
			"ClaudeResp: Error details: %".format(result[\error]).postln;
			^result;
		};

		// Handle successful responses
		result[\isError] = false;

		// Extract content from the response
		if(response['content'].notNil) {
			var content = response['content'];
			"ClaudeResp: Content exists and is: %".format(content).postln;
			"ClaudeResp: Content class: %".format(content.class).postln;

			// Handle array content (common in Claude API)
			if(content.isKindOf(Array) || content.isKindOf(List)) {
				"ClaudeResp: Content is an array with % items".format(content.size).postln;

				content.do { |part, i|
					"ClaudeResp: Processing part %".format(i).postln;

					if(part.isKindOf(Dictionary) || part.isKindOf(Event)) {
						if(part['type'] == "text" && part['text'].notNil) {
							"ClaudeResp: Found text part: %".format(part['text'].keep(50) ++ "...").postln;
							textParts = textParts.add(part['text']);
						};
					};
				};

				if(textParts.size > 0) {
					result[\text] = textParts.join("");
					"ClaudeResp: Extracted text: %".format(result[\text].keep(50) ++ "...").postln;
				} {
					"ClaudeResp: WARNING - No text parts found in content array!".postln;
				};
			} {
				// Direct string content
				if(content.isKindOf(String)) {
					result[\text] = content;
				};
			};
		} {
			// Try alternative content locations
			if(response['text'].notNil) {
				result[\text] = response['text'];
			} {
				"ClaudeResp: Could not find text content. Response structure:".postln;
				response.keysValuesDo { |k, v|
					"  % -> %".format(k, if(v.isKindOf(String)) { v.keep(30) ++ "..." } { v.class }).postln;
				};
			};
		};

		// Extract other useful information
		result[\id] = response['id'];
		result[\model] = response['model'];
		result[\role] = response['role'];
		result[\stopReason] = response['stop_reason'];
		result[\stopSequence] = response['stop_sequence'];
		result[\usage] = response['usage'];
		result[\raw] = response;  // Include the full response for advanced use

		// Final check for text content
		if(result[\text].isNil) {
			"ClaudeResp: WARNING - Failed to extract text from response!".postln;
			"ClaudeResp: Full response dump:".postln;
			response.postln;
		};

		^result;
	}
}

// Main API Class
ClaudeAPI {
	var <conversations;
	var <>currentConversationId;
	var <>model;
	var <>params;

	*new { |apiKey|
		^super.new.init(apiKey);
	}

	init { |apiKey|
		if(apiKey.notNil) {
			ClaudeConfig.setApiKey(apiKey);
		};

		conversations = Dictionary.new;
		model = ClaudeConfig.defaultModel;
		params = ClaudeConfig.defaultParams.copy;

		// Create a default conversation
		this.newConversation;
	}

	newConversation { |id|
		id = id ?? { "conv_%".format(Date.getDate.stamp) };
		conversations[id] = [];
		currentConversationId = id;
		^id;
	}

	setModel { |modelName|
		model = modelName;
	}

	setParam { |key, value|
		params[key] = value;
	}

	addMessage { |role, content, conversationId|
		conversationId = conversationId ?? currentConversationId;

		if(conversations[conversationId].isNil) {
			Error("ClaudeAPI: Conversation ID '%' not found.".format(conversationId)).throw;
		};

		"ClaudeAPI: Adding message with role '%' and content: %".format(role, content.keep(50) ++ "...").postln;

		conversations[conversationId] = conversations[conversationId].add((
			\role: role,
			\content: content
		));

		^conversations[conversationId].size - 1;  // Return the message index
	}

	// Helper method to prepare messages for API
	prepareMessages { |conversationId|
		var messages = [];

		conversationId = conversationId ?? currentConversationId;

		conversations[conversationId].do { |msg|
			messages = messages.add((
				"role": msg[\role],
				"content": msg[\content]
			));
		};

		"ClaudeAPI: Prepared messages: %".format(messages).postln;
		^messages;
	}

	// Send a message and get a response
	chat { |message, onComplete, onFailure, conversationId|
		var messages, requestData, jsonString;

		conversationId = conversationId ?? currentConversationId;

		// Add user message to conversation history
		this.addMessage("user", message, conversationId);

		// Prepare messages from conversation history
		messages = this.prepareMessages(conversationId);

		// Prepare request data - convert symbols to strings for JSON compatibility
		requestData = (
			"model": model,
			"messages": messages,
			"temperature": params[\temperature],
			"max_tokens": params[\max_tokens],
			"top_p": params[\top_p],
			"top_k": params[\top_k]
		);

		// Debug the request data
		"ClaudeAPI: Request data structure:".postln;
		requestData.keysValuesDo { |k, v|
			"  % -> %".format(k, v.class).postln;
		};

		// Convert to JSON string - IMPORTANT: store the result
		jsonString = requestData.asJSON;
		"ClaudeAPI: JSON string length: %".format(jsonString.size).postln;
		if(jsonString.size <= 5) {
			"ClaudeAPI: WARNING - JSON string is too short or empty: '%'".format(jsonString).postln;
			onFailure.value("Failed to create valid JSON from request data");
			^this;
		};

		"ClaudeAPI: Sending request with data: %".format(jsonString.keep(200) ++ "...").postln;

		// Make the API request
		ClaudeReq.makeRequest(
			"messages",
			"POST",
			jsonString,
			{ |response|
				var parsedResponse;
				"ClaudeAPI: Received response, processing...".postln;
				parsedResponse = ClaudeResp.parse(response);

				if(parsedResponse[\isError]) {
					"ClaudeAPI: Error in response: %".format(parsedResponse[\error]).postln;
					onFailure.value(parsedResponse[\error]);
				} {
					if(parsedResponse[\text].isNil) {
						"ClaudeAPI: WARNING - Parsed response has no text content!".postln;
						"ClaudeAPI: Attempting to extract text directly from content array...".postln;

						// Emergency extraction from raw response if parser failed
						try {
							if(response['content'].isKindOf(Array) && response['content'].size > 0) {
								var contentArray = response['content'];
								var textPart = contentArray.detect { |part| part['type'] == "text" };

								if(textPart.notNil && textPart['text'].notNil) {
									"ClaudeAPI: Successfully extracted text directly from content array".postln;
									parsedResponse[\text] = textPart['text'];
								};
							};
						};

						if(parsedResponse[\text].isNil) {
							onFailure.value("Could not extract text from Claude response");
							^this;
						};
					};

					// Success - add assistant's response to conversation history
					this.addMessage("assistant", parsedResponse[\text], conversationId);
					onComplete.value(parsedResponse);
				};
			},
			{ |error| onFailure.value(error); }
		);
	}

	// Simplified method for one-off queries (doesn't maintain conversation)
	ask { |message, onComplete, onFailure|
		var requestData, jsonString;

		"ClaudeAPI: Ask method called with message: %".format(message.keep(50) ++ "...").postln;

		requestData = (
			"model": model,
			"messages": [
				(
					"role": "user",
					"content": message
				)
			],
			"temperature": params[\temperature],
			"max_tokens": params[\max_tokens],
			"top_p": params[\top_p],
			"top_k": params[\top_k]
		);

		// Debug the request data
		"ClaudeAPI: Request data structure:".postln;
		requestData.keysValuesDo { |k, v|
			"  % -> %".format(k, v.class).postln;
		};

		// Convert to JSON string - IMPORTANT: store the result
		jsonString = requestData.asJSON;
		"ClaudeAPI: JSON string length: %".format(jsonString.size).postln;
		if(jsonString.size <= 5) {
			"ClaudeAPI: WARNING - JSON string is too short or empty: '%'".format(jsonString).postln;
			onFailure.value("Failed to create valid JSON from request data");
			^this;
		};

		"ClaudeAPI: Sending request with data: %".format(jsonString.keep(200) ++ "...").postln;

		ClaudeReq.makeRequest(
			"messages",
			"POST",
			jsonString,
			{ |response|
				var parsedResponse = ClaudeResp.parse(response);
				if(parsedResponse[\isError]) {
					onFailure.value(parsedResponse[\error]);
				} {
					if(parsedResponse[\text].isNil) {
						"ClaudeAPI: WARNING - Parsed response has no text content!".postln;
						"ClaudeAPI: Attempting to extract text directly from content array...".postln;

						// Emergency extraction from raw response if parser failed
						try {
							if(response['content'].isKindOf(Array) && response['content'].size > 0) {
								var contentArray = response['content'];
								var textPart = contentArray.detect { |part| part['type'] == "text" };

								if(textPart.notNil && textPart['text'].notNil) {
									"ClaudeAPI: Successfully extracted text directly from content array".postln;
									parsedResponse[\text] = textPart['text'];
								};
							};
						};

						if(parsedResponse[\text].isNil) {
							onFailure.value("Could not extract text from Claude response");
							^this;
						};
					};

					onComplete.value(parsedResponse);
				};
			},
			{ |error| onFailure.value(error); }
		);
	}

	// Get conversation history
	getConversation { |conversationId|
		conversationId = conversationId ?? currentConversationId;
		^conversations[conversationId];
	}

	// Clear conversation history
	clearConversation { |conversationId|
		conversationId = conversationId ?? currentConversationId;
		conversations[conversationId] = [];
	}

	// Delete a conversation
	deleteConversation { |conversationId|
		conversationId = conversationId ?? currentConversationId;
		conversations.removeAt(conversationId);

		if(currentConversationId == conversationId) {
			if(conversations.size > 0) {
				currentConversationId = conversations.keys.asArray[0];
			} {
				this.newConversation;
			};
		};
	}
}

// Example usage - uncomment to test
/*
// Initialize API with your key
~claude = ClaudeAPI("your_api_key_here");

// Optional: Set specific parameters
~claude.setParam(\temperature, 0.5);
~claude.setParam(\max_tokens, 1024);

// Check the temporary directory paths and permissions
(
var tmpDir = Platform.userAppSupportDir +/+ "tmp";
"User app support directory: %".format(Platform.userAppSupportDir).postln;
"Tmp directory path: %".format(tmpDir).postln;
"Does tmp directory exist? %".format(File.exists(tmpDir)).postln;
if(File.exists(tmpDir).not) {
	"Creating tmp directory...".postln;
	File.mkdir(tmpDir);
};
"Can write to tmp directory? %".format(File.writable(tmpDir)).postln;

// Test file creation
var testFile = tmpDir +/+ "test.txt";
try {
	File.use(testFile, "w") { |f| f.write("Test content") };
	"Test file created successfully at: %".format(testFile).postln;
	"Test file size: % bytes".format(File.fileSize(testFile)).postln;
	File.delete(testFile);
} { |error|
	"Error creating test file: %".format(error).postln;
};
)

// Simple direct test of JSON generation - test this first
(
var requestData = (
	"model": "claude-3-7-sonnet-20250219",
	"messages": [(
		"role": "user",
		"content": "Hello"
	)],
	"max_tokens": 100
);
var jsonString = requestData.asJSON;
"JSON string: %".format(jsonString).postln;
"JSON length: %".format(jsonString.size).postln;
)

// Test direct API connection - try this second to verify API works
fork {
	var jsonStr = "{\"model\":\"claude-3-7-sonnet-20250219\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}],\"max_tokens\":100}";
	var curl = "curl -s -X POST 'https://api.anthropic.com/v1/messages' -H 'Content-Type: application/json' -H 'anthropic-version: 2023-06-01' -H 'x-api-key: your_api_key_here' -d '" ++ jsonStr ++ "'";
	var pipe = Pipe.new(curl, "r");
	var result = pipe.getLine;
	pipe.close;
	("Direct test result: " ++ result).postln;
};

// Send a message and handle the response - try this last
~claude.chat("Hello, how are you today?",
	{ |response|
		"Claude says: %".format(response[\text]).postln;
	},
	{ |error|
		"Error: %".format(error).postln;
	}
);
*/