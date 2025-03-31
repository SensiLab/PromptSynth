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
		var attempt;
var doRequest;
		attempt = 0;

		"ClaudeAPI: Making request to endpoint: %".format(endpoint).postln;

		if(ClaudeConfig.apiKey.isNil, {
			Error("ClaudeAPI: API key not set. Use ClaudeConfig.setApiKey first.").throw;
		});

		// Create temporary files for request data and response
		tempFile = PathName.tmp ++ "claudeRequestData" ++ Date.getDate.stamp ++ ".json";
		responseFile = PathName.tmp ++ "claudeResponse" ++ Date.getDate.stamp ++ ".json";

		// Write request data to temp file if provided
		if(data.notNil, {
			"ClaudeAPI: Writing request data to temp file: %".format(tempFile).postln;
			File.use(tempFile, "w", { |f|
				"ClaudeAPI: Request data: %".format(data.keep(200) ++ "...").postln;
				f.write(data);
			});

			// Verify file was written correctly
			"ClaudeAPI: Verifying request data file...".postln;
			if(File.exists(tempFile), {
				var fileSize = File.fileSize(tempFile);
				"ClaudeAPI: Request data file size: % bytes".format(fileSize).postln;
				if(fileSize <= 0, {
					"ClaudeAPI: WARNING - Request data file is empty!".postln;
					Error("ClaudeAPI: Unable to write request data to file.").throw;
				});
			}, {
				"ClaudeAPI: WARNING - Request data file does not exist!".postln;
				Error("ClaudeAPI: Unable to create request data file.").throw;
			});
		});

		// Setup headers
		headers = [
			"Content-Type: application/json",
			"anthropic-version: 2023-06-01",
			"x-api-key: %".format(ClaudeConfig.apiKey)
		];

		// Start a forked process for handling the async request
		fork {
			// Create the curl command with additional options for reliability
			curl = "curl -s -S --retry 3 --retry-delay 2 --connect-timeout 30 -X % '%/%' -H '%' -H '%' -H '%'".format(
				method,
				ClaudeConfig.apiUrl,
				endpoint,
				headers[0],
				headers[1],
				headers[2]
			);

			// Add data if present
			if(data.notNil, {
				curl = curl + " -d @'%'".format(tempFile);
			});

			// Add output file
			curl = curl + " -o '%'".format(responseFile);

			// Recursive retry function
			doRequest = { |currentAttempt|
				// Execute curl command
				"ClaudeAPI: Executing curl command (attempt %/%): %".format(currentAttempt + 1, retryAttempts, curl).postln;
				cmd = curl.unixCmd({ |exitCode|
					"ClaudeAPI: curl completed with exit code %".format(exitCode).postln;

					fork {
						if(exitCode == 0, {
							// Read response
							if(File.exists(responseFile), {
								var response, parsed;

								response = File.use(responseFile, "r", { |f| f.readAllString });

								try {
									"ClaudeAPI: Attempting to parse response: %".format(response.keep(100) ++ "...").postln;
									parsed = response.parseJSON;
									"ClaudeAPI: Successfully parsed response".postln;
									onComplete.value(parsed);
								} {
									"ClaudeAPI: Error parsing response".postln;
									if(currentAttempt < (retryAttempts - 1), {
										"ClaudeAPI: Will retry in % seconds...".format(retryDelay).postln;
										retryDelay.wait;
										doRequest.value(currentAttempt + 1);
									}, {
										onFailure.value("Failed to parse response: %".format(response));
									});
								};

								// Clean up temp files
								File.delete(responseFile);
								if(data.notNil, {
									File.delete(tempFile);
								});
							}, {
								if(currentAttempt < (retryAttempts - 1), {
									"ClaudeAPI: Response file not found. Will retry in % seconds...".format(retryDelay).postln;
									retryDelay.wait;
									doRequest.value(currentAttempt + 1);
								}, {
									onFailure.value("Response file not created");
								});
							});
						}, {
							if(currentAttempt < (retryAttempts - 1), {
								"ClaudeAPI: Curl error (code %). Will retry in % seconds...".format(exitCode, retryDelay).postln;
								retryDelay.wait;
								doRequest.value(currentAttempt + 1);
							}, {
								onFailure.value("Curl error with exit code %".format(exitCode));
							});
						});
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
		var result = ();

		"ClaudeResp: Parsing response...".postln;
		"ClaudeResp: Raw response: %".format(response).postln;

		// Check if there's an error in the response
		if(response.isNil, {
			"ClaudeResp: Response is nil".postln;
			result[\isError] = true;
			result[\error] = "No response received";
			result[\errorType] = "empty_response";
			^result;
		});

		// Debug the full response structure
		"ClaudeResp: Response keys: %".format(response.keys).postln;

		// Check for error field anywhere in the response structure
		if(response['error'].notNil, {
			"ClaudeResp: Found error in response".postln;
			result[\isError] = true;

			if(response['error'].isKindOf(Dictionary) || response['error'].isKindOf(Event), {
				result[\error] = response['error']['message'] ?? "Unknown error";
				result[\errorType] = response['error']['type'] ?? "unknown_error";
				result[\errorCode] = response['error']['status'] ?? 500;
			}, {
				result[\error] = response['error'].asString;
				result[\errorType] = "unknown_error";
			});

			result[\raw] = response;
			"ClaudeResp: Error details: %".format(result[\error]).postln;
			^result;
		});

		// Handle successful responses
		result[\isError] = false;

		// Extract the message content - Claude API format is {"content": [{"type": "text", "text": "..."}]}
		if(response['content'].notNil, {
			var content = response['content'];
			var textParts = [];

			"ClaudeResp: Content format: %".format(content.class).postln;

			if(content.isKindOf(Array) || content.isKindOf(List), {
				// Extract text from each part
				content.do({ |part|
					"ClaudeResp: Processing content part: %".format(part).postln;
					if(part['type'] == "text", {
						textParts = textParts.add(part['text']);
					});
				});

				result[\text] = textParts.join("");
				"ClaudeResp: Extracted text: %".format(result[\text].keep(50) ++ "...").postln;
			}, {
				// Try direct access in case format is different
				"ClaudeResp: Content is not an array, trying direct access".postln;
				if(content.isKindOf(String), {
					result[\text] = content;
				});
			});
		}, {
			// Check if text field exists directly
			if(response['text'].notNil, {
				// Alternative location in case API response format changes
				"ClaudeResp: Using 'text' field directly".postln;
				result[\text] = response['text'];
			}, {
				// Last resort - dump the whole response so we can see what it contained
				"ClaudeResp: Could not find text content. Response structure:".postln;
				response.keysValuesDo({ |k, v|
					"  % -> %".format(k, if(v.isKindOf(String), { v.keep(30) ++ "..." }, { v.class })).postln;
				});
			});
		});

		// Extract other useful information
		result[\id] = response['id'];
		result[\model] = response['model'];
		result[\role] = response['role'];
		result[\stopReason] = response['stop_reason'];
		result[\stopSequence] = response['stop_sequence'];
		result[\usage] = response['usage'];
		result[\raw] = response;  // Include the full response for advanced use

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
		if(apiKey.notNil, {
			ClaudeConfig.setApiKey(apiKey);
		});

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

		if(conversations[conversationId].isNil, {
			Error("ClaudeAPI: Conversation ID '%' not found.".format(conversationId)).throw;
		});

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

		conversations[conversationId].do({ |msg|
			messages = messages.add((
				"role": msg[\role],
				"content": msg[\content]
			));
		});

		"ClaudeAPI: Prepared messages: %".format(messages).postln;
		^messages;
	}

	// Send a message and get a response
	chat { |message, onComplete, onFailure, conversationId|
		var messages, requestData;

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
		requestData.keysValuesDo({ |k, v|
			"  % -> %".format(k, v.class).postln;
		});

		// Convert to JSON
		requestData = requestData.asJSON;
		"ClaudeAPI: Sending request with data: %".format(requestData).postln;

		// Make the API request
		ClaudeReq.makeRequest(
			"messages",
			"POST",
			requestData,
			{ |response|
				var parsedResponse = ClaudeResp.parse(response);
				"ClaudeAPI: Received response, processing...".postln;

				if(parsedResponse[\isError], {
					"ClaudeAPI: Error in response: %".format(parsedResponse[\error]).postln;
					onFailure.value(parsedResponse[\error]);
				}, {
					// Success - add assistant's response to conversation history
					this.addMessage("assistant", parsedResponse[\text], conversationId);
					onComplete.value(parsedResponse);
				});
			},
			{ |error| onFailure.value(error); }
		);
	}

	// Simplified method for one-off queries (doesn't maintain conversation)
	ask { |message, onComplete, onFailure|
		var requestData;

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
		requestData.keysValuesDo({ |k, v|
			"  % -> %".format(k, v.class).postln;
		});

		// Convert to JSON
		requestData = requestData.asJSON;
		"ClaudeAPI: Sending request with data: %".format(requestData).postln;

		ClaudeReq.makeRequest(
			"messages",
			"POST",
			requestData,
			{ |response|
				var parsedResponse = ClaudeResp.parse(response);
				if(parsedResponse[\isError], {
					onFailure.value(parsedResponse[\error]);
				}, {
					onComplete.value(parsedResponse);
				});
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

		if(currentConversationId == conversationId, {
			if(conversations.size > 0, {
				currentConversationId = conversations.keys.asArray[0];
			}, {
				this.newConversation;
			});
		});
	}
}

// Example usage - uncomment to test
/*
// Initialize API with your key
~claude = ClaudeAPI("your_api_key_here");

// Optional: Set specific parameters
~claude.setParam(\temperature, 0.5);
~claude.setParam(\max_tokens, 1024);

// Test direct API connection - simplest approach to verify API works
fork {
	var curl = "curl -s -X POST 'https://api.anthropic.com/v1/messages' -H 'Content-Type: application/json' -H 'anthropic-version: 2023-06-01' -H 'x-api-key: your_api_key_here' -d '{\"model\":\"claude-3-7-sonnet-20250219\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}],\"max_tokens\":100}'";
	var pipe = Pipe.new(curl, "r");
	var result = pipe.getLine;
	pipe.close;
	("Direct test result: " ++ result).postln;
};

// Send a message and handle the response
~claude.chat("Hello, how are you today?",
	{ |response|
		"Claude says: %".format(response[\text]).postln;
	},
	{ |error|
		"Error: %".format(error).postln;
	}
);

// One-off question without maintaining conversation
~claude.ask("What is the capital of France?",
	{ |response|
		"Answer: %".format(response[\text]).postln;
	},
	{ |error|
		"Error: %".format(error).postln;
	}
);
*/