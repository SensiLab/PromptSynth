// Anthropic API for SuperCollider using JSONlib
// Requires JSONlib quark: Quarks.install("JSONlib")

Anthropic{
	classvar <uris;
	classvar <>apiKey;
	classvar <>model = "claude-3-5-sonnet-20241022";
	classvar <>maxTokens = 1000;
	classvar <>temperature = 0.7;
	classvar <>version = "2023-06-01";
	classvar <>keyFile;

	*initClass{
		uris = (
			\BASE: "https://api.anthropic.com/v1",
			\MESSAGES: "/messages",
			\COMPLETE: "/complete"
		);

		keyFile = PathName(Anthropic.class.filenameSymbol.asString).pathOnly;
		keyFile = keyFile ++ Platform.pathSeparator ++ "anthropic_key.txt";

		// Check if JSONlib is available
		if(JSONlib.isNil) {
			"WARNING: JSONlib quark not found. Install with: Quarks.install(\"JSONlib\")".postln;
		};
	}

	*uri{|uri_key|
		^(uris[\BASE] ++ uris[uri_key]);
	}

	*loadApiKey{
		if(apiKey.isNil) {
			if(File.exists(keyFile)) {
				try {
					apiKey = File(keyFile, "r").readAllString.stripWhiteSpace;
					"Anthropic API key loaded from file".postln;
				} {
					"Error loading API key from file".postln;
				}
			} {
				"API key file not found. Please set Anthropic.apiKey or create %".format(keyFile).postln;
			}
		};
	}

	*saveApiKey{|key|
		apiKey = key;
		try {
			File(keyFile, "w").write(key).close;
			"API key saved to %".format(keyFile).postln;
		} {
			"Error saving API key to file".postln;
		}
	}
}

AnthropicReq{
	var <url, <filePath, <cmd, <payload, <headers;

	*new{|anUrl, payload, method="POST"|
		Anthropic.loadApiKey;
		if(Anthropic.apiKey.isNil or: {Anthropic.apiKey.isEmpty}) {
			throw("Anthropic API key is not set! Use Anthropic.apiKey = \"your_key\" or Anthropic.saveApiKey(\"your_key\")");
		};
		^super.new.init(anUrl, payload, method);
	}

	*getHeaders{
		^[
			"Content-Type: application/json",
			"x-api-key: %".format(Anthropic.apiKey),
			"anthropic-version: %".format(Anthropic.version)
		];
	}

	init{|anUrl, aPayload, method="POST"|
		var jsonString, payloadFile, headerString;

		url = anUrl;
		payload = aPayload;
		filePath = PathName.tmp ++ "anthropic_" ++ UniqueID.next ++ ".json";
		headers = AnthropicReq.getHeaders;

		headerString = "";
		headers.do({|h|
			headerString = headerString ++ "-H \"" ++ h ++ "\" ";
		});

		cmd = "curl -s -X % %".format(method, headerString);

		if(payload.notNil) {
			// Use basic JSON encoding (JSONlib doesn't have stringify)
			jsonString = AnthropicReq.basicJSON(payload);

			payloadFile = PathName.tmp ++ "anthropic_payload_" ++ UniqueID.next ++ ".json";

			// Debug: print the JSON being sent
			"Generated JSON payload:".postln;
			jsonString.postln;
			"JSON length: %".format(jsonString.size).postln;

			File(payloadFile, "w").write(jsonString).close;
			cmd = cmd ++ " -d @\"%\"".format(payloadFile);
		};

		cmd = cmd ++ " \"%\" > \"%\"".format(url, filePath);

		// Debug: print the full curl command
		"Curl command:".postln;
		cmd.postln;
	}

	// Fallback basic JSON encoder if JSONlib is not available
	*basicJSON{|obj|
		^case
		{obj.isNil} {"null"}
		{obj.isKindOf(String)} {
			"\"" ++ obj.replace("\\", "\\\\")
					  .replace("\"", "\\\"")
					  .replace("\n", "\\n")
					  .replace("\r", "\\r")
					  .replace("\t", "\\t") ++ "\""
		}
		{obj.isKindOf(Symbol)} {
			"\"" ++ obj.asString.replace("\\", "\\\\")
							   .replace("\"", "\\\"") ++ "\""
		}
		{obj.isKindOf(Number)} {obj.asString}
		{obj.isKindOf(Boolean)} {obj.asString.toLower}
		{obj.isKindOf(Array)} {
			var items = obj.collect({|item| AnthropicReq.basicJSON(item)});
			"[" ++ AnthropicReq.joinArray(items, ",") ++ "]"
		}
		{obj.isKindOf(Dictionary) or: {obj.isKindOf(Event)}} {
			var pairs = obj.keys.collect({|key|
				"\"" ++ key.asString ++ "\":" ++ AnthropicReq.basicJSON(obj[key])
			});
			"{" ++ AnthropicReq.joinArray(pairs, ",") ++ "}"
		}
		{obj.asString};
	}

	*joinArray{|array, separator|
		var result = "";
		array.do({|item, i|
			result = result ++ item;
			if(i < (array.size - 1)) {
				result = result ++ separator;
			};
		});
		^result;
	}

	execute{|action, objClass|
		cmd.unixCmd({|res, pid|
			var obj = nil;
			var str = "";

			if(File.exists(filePath)) {
				str = File(filePath, "r").readAllString;
				File.delete(filePath);
			};

			if(str.size > 0) {
				try {
					var parsed;
					// Use JSONlib for parsing if available
					if(JSONlib.notNil) {
						parsed = parseJSON(str);
					} {
						"JSONlib not available, falling back to parseYAML".postln;
						parsed = str.parseYAML;
					};

					if(parsed.includesKey("error")) {
						"Anthropic API Error: %".format(parsed["error"]).postln;
						obj = AnthropicError.new(parsed);
					} {
						obj = objClass.new(parsed);
					};
				} {
					"Error parsing response: %".format(str).postln;
					obj = AnthropicError.new(("error": "Parse error", "raw": str));
				};
			} {
				"Empty response from Anthropic API".postln;
				obj = AnthropicError.new(("error": "Empty response"));
			};

			action.value(obj);
		});
	}
}

AnthropicObj : Object{
	var <dict;

	*new{|jsonDict|
		^super.new.init(jsonDict);
	}

	init{|jsonDict|
		dict = jsonDict.as(Dictionary);
		dict.keysDo{|k|
			this.addUniqueMethod(k.replace("-", "_").asSymbol, {
				var obj = dict[k];
				if(obj.isKindOf(Dictionary)) {obj = AnthropicObj.new(obj)};
				obj;
			});
		};
	}

	at{|x| ^this.dict.at(x)}

	hasError{
		^dict.includesKey("error");
	}

	errorMessage{
		if(this.hasError) {
			^dict["error"]["message"] ? dict["error"];
		};
		^nil;
	}
}

AnthropicError : AnthropicObj{
	printOn{|stream|
		stream << "AnthropicError(" << this.errorMessage << ")";
	}
}

AnthropicMessage : AnthropicObj{
	*create{|messages, systemPrompt, model, maxTokens, temperature, action|
		var payload = (
			"model": model ? Anthropic.model,
			"max_tokens": maxTokens ? Anthropic.maxTokens,
			"temperature": temperature ? Anthropic.temperature,
			"messages": messages
		);

		if(systemPrompt.notNil) {
			payload["system"] = systemPrompt;
		};

		AnthropicReq.new(Anthropic.uri(\MESSAGES), payload).execute(action, AnthropicMessage);
	}

	*simpleCompletion{|prompt, systemPrompt, action|
		var messages = [
			("role": "user", "content": prompt)
		];

		AnthropicMessage.create(messages, systemPrompt, action: action);
	}

	*codeGeneration{|prompt, language="supercollider", action|
		var systemPrompt = "You are a % expert. Generate clean, well-commented code.".format(language);
		var userPrompt = "Generate % code for: %".format(language, prompt);

		AnthropicMessage.simpleCompletion(userPrompt, systemPrompt, action);
	}

	getText{
		var contentArray, textParts;

		if(this.hasError) {
			^"Error: " ++ this.errorMessage;
		};

		if(dict.includesKey("content") and: {dict["content"].isArray}) {
			contentArray = dict["content"];
			textParts = [];

			contentArray.do({|block|
				if(block.includesKey("text")) {
					textParts = textParts.add(block["text"]);
				} {
					textParts = textParts.add(block.asString);
				}
			});

			^AnthropicReq.joinArray(textParts, "\n");
		};

		^dict.asString;
	}

	getCodeBlocks{|language|
		var text = this.getText;
		var pattern = "```%?([\\s\\S]*?)```".format(language ? "");
		var matches = text.findRegexp(pattern);
		var codeBlocks = [];
		
		if(matches.notNil and: {matches.isArray}) {
			matches.do({|match|
				if(match.isArray and: {match.size > 1}) {
					codeBlocks = codeBlocks.add(match[1]);
				};
			});
		};
		
		^codeBlocks;
	}

	usage{
		^dict["usage"];
	}
}

// Backwards compatibility with the original API
AnthropicLegacy{
	*makeApiCall{|prompt, maxTokens=100, action|
		AnthropicMessage.simpleCompletion(prompt, action: {|response|
			var result;
			if(response.hasError) {
				result = ("error": response.errorMessage);
			} {
				result = ("completion": response.getText);
			};
			action.value(result);
		}, maxTokens: maxTokens);
	}
}

// Convenience methods
+Anthropic{
	*complete{|prompt, action|
		AnthropicMessage.simpleCompletion(prompt, action: action);
	}

	*chat{|messages, systemPrompt, action|
		AnthropicMessage.create(messages, systemPrompt, action: action);
	}

	*generateCode{|prompt, language="supercollider", action|
		AnthropicMessage.codeGeneration(prompt, language, action);
	}
}