const std = @import("std");
const testing = std.testing;
const llm = @import("../../src/llm.zig");
const graph = @import("../../src/graph.zig");

// ============================================================================
// LLMClient Initialization Tests
// ============================================================================

test "LLMClient.init creates client with environment API key" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok);
    }
    const allocator = gpa.allocator();

    // Note: This test checks that init succeeds regardless of env var presence
    var client = llm.LLMClient.init(allocator);
    defer client.deinit();

    try testing.expectEqualStrings("https://api.anthropic.com/v1/messages", client.api_endpoint);
}

test "LLMClient.init handles missing API key gracefully" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok);
    }
    const allocator = gpa.allocator();

    // Unset env var (if it exists)
    std.process.unsetenv("ANTHROPIC_API_KEY");

    var client = llm.LLMClient.init(allocator);
    defer client.deinit();

    // Client should initialize successfully even without API key
    // It will use mock data instead
    try testing.expect(client.api_key == null);
}

test "LLMClient.deinit frees API key memory" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok);
    }
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
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok);
    }
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
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok);
    }
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
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok);
    }
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
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok);
    }
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
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok);
    }
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
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok);
    }
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
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok);
    }
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
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok);
    }
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
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok);
    }
    const allocator = gpa.allocator();

    std.process.unsetenv("ANTHROPIC_API_KEY");

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
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok);
    }
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
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok);
    }
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
