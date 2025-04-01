// Simple Claude API wrapper class for SuperCollider
ClaudeAPI {
  var <apiKey;

  *new { |key|
    ^super.new.init(key);
  }

  init { |key|
    apiKey = key;
  }

  // Send a message to Claude and get just the text response
  ask { |message, onComplete, onFailure|
    var tempFile, responseFile, curl, cmd;
    var tmpDir = Platform.userAppSupportDir +/+ "tmp";

    // Create temp directory if it doesn't exist
    if(File.exists(tmpDir).not) {
      File.mkdir(tmpDir);
    };

    // Create temporary files
    tempFile = tmpDir +/+ "claude_request_" ++ Date.getDate.stamp ++ ".json";
    responseFile = tmpDir +/+ "claude_response_" ++ Date.getDate.stamp ++ ".json";

    // Create the request JSON
    File.use(tempFile, "w") { |f|
      var requestData = (
        model: "claude-3-7-sonnet-20250219",
        messages: [(
          role: "user",
          content: message
        )],
        max_tokens: 4096
      ).asJSON;

      f.write(requestData);
    };

    // Build the curl command
    curl = "curl -s -X POST 'https://api.anthropic.com/v1/messages' " ++
           "-H 'Content-Type: application/json' " ++
           "-H 'anthropic-version: 2023-06-01' " ++
           "-H 'x-api-key: %' ".format(apiKey) ++
           "-d @'%' ".format(tempFile) ++
           "-o '%'".format(responseFile);

    // Execute the command
    fork {
      cmd = curl.unixCmd { |exitCode|
        if(exitCode == 0) {
          if(File.exists(responseFile)) {
            var response = File.use(responseFile, "r") { |f| f.readAllString };
            var parsed;

            try {
              parsed = response.parseJSON;

              // Extract the text from the response
              if(parsed['content'].notNil && parsed['content'].isArray) {
                var content = parsed['content'];
                var textParts = [];

                content.do { |part|
                  if(part['type'] == "text" && part['text'].notNil) {
                    textParts = textParts.add(part['text']);
                  };
                };

                if(textParts.size > 0) {
                  var text = textParts.join("");
                  onComplete.value(text);
                } {
                  onFailure.value("No text content found in response");
                };
              } {
                onFailure.value("Invalid response format");
              };
            } {
              onFailure.value("Failed to parse JSON response");
            };

            // Clean up temp files
            File.delete(responseFile);
            File.delete(tempFile);
          } {
            onFailure.value("Response file not created");
          };
        } {
          onFailure.value("curl error: %".format(exitCode));
        };
      };
    };
  }
}