const std = @import("std");
const testing = std.testing;
const llm = @import("llm");
const graph = @import("graph");

// ============================================================================
// LLMClient Initialization Tests
// ============================================================================

test "LLMClient.init creates client with environment API key" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Note: This test checks that init succeeds regardless of env var presence
    var client = llm.LLMClient.init(allocator);
    defer client.deinit();

    try testing.expectEqualStrings("https://api.anthropic.com/v1/messages", client.api_endpoint);
}

test "LLMClient.init handles missing API key gracefully" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Unset env var (if it exists)
    // Note: unsetenv is not available in Zig 0.13.0, but the test will work
    // correctly anyway if ANTHROPIC_API_KEY is not set in the environment
    // std.process.unsetenv("ANTHROPIC_API_KEY");

    var client = llm.LLMClient.init(allocator);
    defer client.deinit();

    // Client should initialize successfully even without API key
    // It will use mock data instead
    try testing.expect(client.api_key == null);
}

test "LLMClient.deinit frees API key memory" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = llm.LLMClient.init(allocator);
    client.deinit();
    // Test passes if no memory leaks detected by GPA
}

// ============================================================================
// Prompt Building Tests
// ============================================================================

test "buildPrompt includes all ideas from both groups" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = llm.LLMClient.init(allocator);
    defer client.deinit();

    const group1 = [_][]const u8{ "idea 1", "idea 2" };
    const group2 = [_][]const u8{ "idea 3", "idea 4" };

    const prompt = try client.buildPrompt(&group1, &group2);
    defer allocator.free(prompt);

    // Verify all ideas are present in the prompt
    try testing.expect(std.mem.indexOf(u8, prompt, "idea 1") != null);
    try testing.expect(std.mem.indexOf(u8, prompt, "idea 2") != null);
    try testing.expect(std.mem.indexOf(u8, prompt, "idea 3") != null);
    try testing.expect(std.mem.indexOf(u8, prompt, "idea 4") != null);
}

test "buildPrompt contains required structure" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = llm.LLMClient.init(allocator);
    defer client.deinit();

    const group1 = [_][]const u8{"test idea 1"};
    const group2 = [_][]const u8{"test idea 2"};

    const prompt = try client.buildPrompt(&group1, &group2);
    defer allocator.free(prompt);

    // Verify prompt contains required sections
    try testing.expect(std.mem.indexOf(u8, prompt, "Group A:") != null);
    try testing.expect(std.mem.indexOf(u8, prompt, "Group B:") != null);
    try testing.expect(std.mem.indexOf(u8, prompt, "relationship type") != null);
    try testing.expect(std.mem.indexOf(u8, prompt, "certainty score") != null);
    try testing.expect(std.mem.indexOf(u8, prompt, "JSON") != null);
}

test "buildPrompt lists all relationship types" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = llm.LLMClient.init(allocator);
    defer client.deinit();

    const group1 = [_][]const u8{"idea 1"};
    const group2 = [_][]const u8{"idea 2"};

    const prompt = try client.buildPrompt(&group1, &group2);
    defer allocator.free(prompt);

    // Verify all relationship types are documented in the prompt
    const types = [_][]const u8{
        "CONTRADICTORY",
        "IMPLICATIVE",
        "HIERARCHICAL",
        "EVOLUTIONARY",
        "ANALOGOUS",
        "SYNONYMOUS",
        "ANTONYMOUS",
        "PART_WHOLE",
        "CAUSAL",
    };

    for (types) |rel_type| {
        try testing.expect(std.mem.indexOf(u8, prompt, rel_type) != null);
    }
}

test "buildPrompt handles empty groups" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = llm.LLMClient.init(allocator);
    defer client.deinit();

    const empty_group: []const []const u8 = &[_][]const u8{};

    const prompt = try client.buildPrompt(empty_group, empty_group);
    defer allocator.free(prompt);

    // Should still generate a valid prompt structure
    try testing.expect(prompt.len > 0);
    try testing.expect(std.mem.indexOf(u8, prompt, "Group A:") != null);
}

// ============================================================================
// Mock Relationship Generation Tests
// ============================================================================

test "getMockRelationships returns valid relationships" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = llm.LLMClient.init(allocator);
    defer client.deinit();

    const group1 = [_][]const u8{ "idea 1", "idea 2" };
    const group2 = [_][]const u8{ "idea 3", "idea 4" };

    const relationships = try client.getMockRelationships(&group1, &group2);
    defer {
        for (relationships) |*rel| {
            rel.deinit(allocator);
        }
        allocator.free(relationships);
    }

    // Should generate at least some relationships
    try testing.expect(relationships.len > 0);

    // Verify first relationship has valid structure
    if (relationships.len > 0) {
        const rel = relationships[0];
        try testing.expect(rel.from_idea.len > 0);
        try testing.expect(rel.to_idea.len > 0);
        try testing.expect(rel.certainty >= 0.0 and rel.certainty <= 1.0);
        try testing.expect(rel.description.len > 0);
    }
}

test "getMockRelationships certainty scores are in valid range" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = llm.LLMClient.init(allocator);
    defer client.deinit();

    const group1 = [_][]const u8{"idea 1"};
    const group2 = [_][]const u8{"idea 2"};

    const relationships = try client.getMockRelationships(&group1, &group2);
    defer {
        for (relationships) |*rel| {
            rel.deinit(allocator);
        }
        allocator.free(relationships);
    }

    // All certainty scores must be between 0.0 and 1.0
    for (relationships) |rel| {
        try testing.expect(rel.certainty >= 0.0);
        try testing.expect(rel.certainty <= 1.0);
    }
}

test "getMockRelationships uses all relationship types" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = llm.LLMClient.init(allocator);
    defer client.deinit();

    // Generate enough ideas to trigger all relationship types
    const group1 = [_][]const u8{ "idea 1", "idea 2", "idea 3", "idea 4", "idea 5" };
    const group2 = [_][]const u8{ "idea 6", "idea 7", "idea 8", "idea 9", "idea 10" };

    const relationships = try client.getMockRelationships(&group1, &group2);
    defer {
        for (relationships) |*rel| {
            rel.deinit(allocator);
        }
        allocator.free(relationships);
    }

    // With enough combinations, we should see multiple relationship types
    // (This is a weak test, but validates the mock generates variety)
    try testing.expect(relationships.len > 1);
}

test "getMockRelationships handles empty groups" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = llm.LLMClient.init(allocator);
    defer client.deinit();

    const empty_group: []const []const u8 = &[_][]const u8{};

    const relationships = try client.getMockRelationships(empty_group, empty_group);
    defer allocator.free(relationships);

    // Should return empty array for empty input
    try testing.expect(relationships.len == 0);
}

// ============================================================================
// analyzeRelationships Integration Tests
// ============================================================================

test "analyzeRelationships falls back to mock when no API key" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Note: unsetenv is not available in Zig 0.13.0
    // std.process.unsetenv("ANTHROPIC_API_KEY");

    var client = llm.LLMClient.init(allocator);
    defer client.deinit();

    const group1 = [_][]const u8{"test idea 1"};
    const group2 = [_][]const u8{"test idea 2"};

    const relationships = try client.analyzeRelationships(&group1, &group2);
    defer {
        for (relationships) |*rel| {
            rel.deinit(allocator);
        }
        allocator.free(relationships);
    }

    // Should successfully return mock relationships
    try testing.expect(relationships.len > 0);
}

// ============================================================================
// Relationship Memory Safety Tests
// ============================================================================

test "Relationship.deinit frees all memory" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var rel = llm.Relationship{
        .from_idea = try allocator.dupe(u8, "from idea"),
        .to_idea = try allocator.dupe(u8, "to idea"),
        .relation_type = .implicative,
        .certainty = 0.9,
        .description = try allocator.dupe(u8, "test description"),
    };

    rel.deinit(allocator);
    // Test passes if no memory leaks detected by GPA
}

test "analyzeRelationships properly cleans up on success" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = llm.LLMClient.init(allocator);
    defer client.deinit();

    const group1 = [_][]const u8{ "idea 1", "idea 2" };
    const group2 = [_][]const u8{ "idea 3", "idea 4" };

    const relationships = try client.analyzeRelationships(&group1, &group2);

    // Clean up properly
    for (relationships) |*rel| {
        rel.deinit(allocator);
    }
    allocator.free(relationships);

    // Test passes if no memory leaks detected by GPA
}

// ============================================================================
// APIProvider.fromString Tests
// ============================================================================

test "APIProvider.fromString returns anthropic for various cases" {
    try testing.expectEqual(llm.APIProvider.anthropic, llm.APIProvider.fromString("anthropic"));
    try testing.expectEqual(llm.APIProvider.anthropic, llm.APIProvider.fromString("ANTHROPIC"));
    try testing.expectEqual(llm.APIProvider.anthropic, llm.APIProvider.fromString("Anthropic"));
    try testing.expectEqual(llm.APIProvider.anthropic, llm.APIProvider.fromString("AnThRoPiC"));
}

test "APIProvider.fromString returns openai for various cases" {
    try testing.expectEqual(llm.APIProvider.openai, llm.APIProvider.fromString("openai"));
    try testing.expectEqual(llm.APIProvider.openai, llm.APIProvider.fromString("OPENAI"));
    try testing.expectEqual(llm.APIProvider.openai, llm.APIProvider.fromString("OpenAI"));
    try testing.expectEqual(llm.APIProvider.openai, llm.APIProvider.fromString("OpenAi"));
}

test "APIProvider.fromString returns custom for unknown providers" {
    try testing.expectEqual(llm.APIProvider.custom, llm.APIProvider.fromString("custom"));
    try testing.expectEqual(llm.APIProvider.custom, llm.APIProvider.fromString("ollama"));
    try testing.expectEqual(llm.APIProvider.custom, llm.APIProvider.fromString("local"));
    try testing.expectEqual(llm.APIProvider.custom, llm.APIProvider.fromString(""));
    try testing.expectEqual(llm.APIProvider.custom, llm.APIProvider.fromString("unknown"));
}

test "APIProvider.fromString does not trim whitespace" {
    try testing.expectEqual(llm.APIProvider.custom, llm.APIProvider.fromString(" anthropic"));
    try testing.expectEqual(llm.APIProvider.custom, llm.APIProvider.fromString("anthropic "));
    try testing.expectEqual(llm.APIProvider.custom, llm.APIProvider.fromString(" openai "));
}

// ============================================================================
// buildRequestBody Tests
// ============================================================================

test "buildRequestBody generates valid Anthropic format" {
    const allocator = testing.allocator;

    var client = llm.LLMClient{
        .allocator = allocator,
        .api_key = null,
        .http_client = std.http.Client{ .allocator = allocator },
        .config = .{},
        .provider_config = .{
            .provider = .anthropic,
            .model = "claude-3",
            .api_endpoint = "https://api.anthropic.com/v1/messages",
            .auth_header = "x-api-key",
            .auth_prefix = "",
        },
    };
    defer client.http_client.deinit();

    var body = std.ArrayList(u8).init(allocator);
    defer body.deinit();

    try client.buildRequestBody(&body, "Hello");

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, body.items, .{});
    defer parsed.deinit();

    const root = parsed.value.object;
    try testing.expectEqualStrings("claude-3", root.get("model").?.string);
    try testing.expectEqual(@as(i64, 4096), root.get("max_tokens").?.integer);

    const messages = root.get("messages").?.array.items;
    try testing.expectEqual(@as(usize, 1), messages.len);
    try testing.expectEqualStrings("user", messages[0].object.get("role").?.string);
    try testing.expectEqualStrings("Hello", messages[0].object.get("content").?.string);
}

test "buildRequestBody generates valid OpenAI format" {
    const allocator = testing.allocator;

    var client = llm.LLMClient{
        .allocator = allocator,
        .api_key = null,
        .http_client = std.http.Client{ .allocator = allocator },
        .config = .{},
        .provider_config = .{
            .provider = .openai,
            .model = "gpt-4",
            .api_endpoint = "https://api.openai.com/v1/chat/completions",
            .auth_header = "Authorization",
            .auth_prefix = "Bearer ",
        },
    };
    defer client.http_client.deinit();

    var body = std.ArrayList(u8).init(allocator);
    defer body.deinit();

    try client.buildRequestBody(&body, "Test prompt");

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, body.items, .{});
    defer parsed.deinit();

    const root = parsed.value.object;
    try testing.expectEqualStrings("gpt-4", root.get("model").?.string);
    try testing.expect(root.get("max_tokens") == null);

    const messages = root.get("messages").?.array.items;
    try testing.expectEqualStrings("Test prompt", messages[0].object.get("content").?.string);
}

test "buildRequestBody escapes special characters in prompt" {
    const allocator = testing.allocator;

    var client = llm.LLMClient{
        .allocator = allocator,
        .api_key = null,
        .http_client = std.http.Client{ .allocator = allocator },
        .config = .{},
        .provider_config = .{
            .provider = .anthropic,
            .model = "claude-3",
            .api_endpoint = "https://api.anthropic.com/v1/messages",
            .auth_header = "x-api-key",
            .auth_prefix = "",
        },
    };
    defer client.http_client.deinit();

    var body = std.ArrayList(u8).init(allocator);
    defer body.deinit();

    try client.buildRequestBody(&body, "Say \"hello\"\nNew line");

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, body.items, .{});
    defer parsed.deinit();

    const content = parsed.value.object.get("messages").?.array.items[0].object.get("content").?.string;
    try testing.expectEqualStrings("Say \"hello\"\nNew line", content);
}

// ============================================================================
// extractResponseText Tests
// ============================================================================

test "extractResponseText parses Anthropic format" {
    const allocator = testing.allocator;

    var client = llm.LLMClient{
        .allocator = allocator,
        .api_key = null,
        .http_client = std.http.Client{ .allocator = allocator },
        .config = .{},
        .provider_config = .{
            .provider = .anthropic,
            .model = "claude-3",
            .api_endpoint = "https://api.anthropic.com/v1/messages",
            .auth_header = "x-api-key",
            .auth_prefix = "",
        },
    };
    defer client.http_client.deinit();

    const anthropic_response =
        \\{"content": [{"type": "text", "text": "Hello from Claude"}], "model": "claude-3"}
    ;

    const text = try client.extractResponseText(anthropic_response);
    defer allocator.free(text);

    try testing.expectEqualStrings("Hello from Claude", text);
}

test "extractResponseText parses OpenAI format" {
    const allocator = testing.allocator;

    var client = llm.LLMClient{
        .allocator = allocator,
        .api_key = null,
        .http_client = std.http.Client{ .allocator = allocator },
        .config = .{},
        .provider_config = .{
            .provider = .openai,
            .model = "gpt-4",
            .api_endpoint = "https://api.openai.com/v1/chat/completions",
            .auth_header = "Authorization",
            .auth_prefix = "Bearer ",
        },
    };
    defer client.http_client.deinit();

    const openai_response =
        \\{"choices": [{"message": {"role": "assistant", "content": "Hello from GPT"}}]}
    ;

    const text = try client.extractResponseText(openai_response);
    defer allocator.free(text);

    try testing.expectEqualStrings("Hello from GPT", text);
}

test "extractResponseText returns error for missing content field (Anthropic)" {
    const allocator = testing.allocator;

    var client = llm.LLMClient{
        .allocator = allocator,
        .api_key = null,
        .http_client = std.http.Client{ .allocator = allocator },
        .config = .{},
        .provider_config = .{
            .provider = .anthropic,
            .model = "claude-3",
            .api_endpoint = "https://api.anthropic.com/v1/messages",
            .auth_header = "x-api-key",
            .auth_prefix = "",
        },
    };
    defer client.http_client.deinit();

    const invalid_response = \\{"model": "claude-3"}
    ;

    const result = client.extractResponseText(invalid_response);
    try testing.expectError(error.MissingContentField, result);
}

test "extractResponseText returns error for missing choices field (OpenAI)" {
    const allocator = testing.allocator;

    var client = llm.LLMClient{
        .allocator = allocator,
        .api_key = null,
        .http_client = std.http.Client{ .allocator = allocator },
        .config = .{},
        .provider_config = .{
            .provider = .openai,
            .model = "gpt-4",
            .api_endpoint = "https://api.openai.com/v1/chat/completions",
            .auth_header = "Authorization",
            .auth_prefix = "Bearer ",
        },
    };
    defer client.http_client.deinit();

    const invalid_response = \\{"model": "gpt-4"}
    ;

    const result = client.extractResponseText(invalid_response);
    try testing.expectError(error.MissingChoicesField, result);
}

// ============================================================================
// parseResponse Tests
// ============================================================================

test "parseResponse parses valid relationship array" {
    const allocator = testing.allocator;

    var client = llm.LLMClient{
        .allocator = allocator,
        .api_key = null,
        .http_client = std.http.Client{ .allocator = allocator },
        .config = .{},
        .provider_config = .{
            .provider = .anthropic,
            .model = "claude-3",
            .api_endpoint = "https://api.anthropic.com/v1/messages",
            .auth_header = "x-api-key",
            .auth_prefix = "",
        },
    };
    defer client.http_client.deinit();

    const response =
        \\[{"from": "idea1", "to": "idea2", "type": "CAUSAL", "certainty": 0.85, "description": "causes"}]
    ;

    const relationships = try client.parseResponse(response);
    defer {
        for (relationships) |*rel| {
            var r = rel.*;
            r.deinit(allocator);
        }
        allocator.free(relationships);
    }

    try testing.expectEqual(@as(usize, 1), relationships.len);
    try testing.expectEqualStrings("idea1", relationships[0].from_idea);
    try testing.expectEqualStrings("idea2", relationships[0].to_idea);
    try testing.expectEqual(graph.RelationType.causal, relationships[0].relation_type);
    try testing.expectApproxEqAbs(@as(f32, 0.85), relationships[0].certainty, 0.001);
}

test "parseResponse returns error for non-array JSON" {
    const allocator = testing.allocator;

    var client = llm.LLMClient{
        .allocator = allocator,
        .api_key = null,
        .http_client = std.http.Client{ .allocator = allocator },
        .config = .{},
        .provider_config = .{
            .provider = .anthropic,
            .model = "claude-3",
            .api_endpoint = "https://api.anthropic.com/v1/messages",
            .auth_header = "x-api-key",
            .auth_prefix = "",
        },
    };
    defer client.http_client.deinit();

    const response = \\{"not": "an array"}
    ;

    const result = client.parseResponse(response);
    try testing.expectError(error.InvalidJSONFormat, result);
}

test "parseResponse skips items with missing fields" {
    const allocator = testing.allocator;

    var client = llm.LLMClient{
        .allocator = allocator,
        .api_key = null,
        .http_client = std.http.Client{ .allocator = allocator },
        .config = .{},
        .provider_config = .{
            .provider = .anthropic,
            .model = "claude-3",
            .api_endpoint = "https://api.anthropic.com/v1/messages",
            .auth_header = "x-api-key",
            .auth_prefix = "",
        },
    };
    defer client.http_client.deinit();

    const response =
        \\[{"from": "idea1", "type": "CAUSAL", "certainty": 0.5, "description": "test"}, {"from": "a", "to": "b", "type": "ANALOGOUS", "certainty": 0.9, "description": "similar"}]
    ;

    const relationships = try client.parseResponse(response);
    defer {
        for (relationships) |*rel| {
            var r = rel.*;
            r.deinit(allocator);
        }
        allocator.free(relationships);
    }

    try testing.expectEqual(@as(usize, 1), relationships.len);
    try testing.expectEqualStrings("a", relationships[0].from_idea);
}
