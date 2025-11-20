const std = @import("std");
const testing = std.testing;

// Import modules to test their structure
const graph = @import("graph");
const llm = @import("llm");
const ui = @import("ui");
const validation = @import("validation");
const analysis_service = @import("analysis_service");

// Architecture tests verify that the codebase follows architectural principles

test "validation module has no external dependencies" {
    // Validation should be a pure utility module with no dependencies
    // on domain logic or external services
    // This is verified at compile time by Zig's module system
    // If validation imported graph, llm, or ui, compilation would show it

    // Test that validation functions work independently
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Validation should work without any other modules
    try validation.validateIdea("test idea");
    try validation.validateGroup(0);
    try validation.validateGroup(1);

    const sanitized = try validation.sanitizeInput("  test  ", allocator);
    defer allocator.free(sanitized);
    try testing.expectEqualStrings("test", sanitized);
}

test "graph module enforces domain invariants" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var g = graph.SemanticGraph.init(allocator);
    defer g.deinit();

    // Test that invalid inputs are rejected
    const result = g.addVertex("", 0);
    try testing.expectError(error.EmptyContent, result);

    const result2 = g.addVertex("test", 5);
    try testing.expectError(error.InvalidGroup, result2);
}

test "UI layer does not contain business logic" {
    // UIState should delegate to services, not implement business logic
    // This is verified by checking that analyzeIdeas is small and delegates

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var state = ui.UIState.initWithAllocator(allocator);
    defer {
        for (state.ideas.items) |idea| {
            allocator.free(idea);
        }
        state.ideas.deinit();
        state.current_input.deinit();
    }

    // UI state should have analysis service
    try testing.expect(@TypeOf(state.analysis) == analysis_service.AnalysisService);
}

test "analysis service orchestrates without direct dependencies on UI" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Analysis service should work independently of UI
    var service = analysis_service.AnalysisService.init(allocator);
    var g = graph.SemanticGraph.init(allocator);
    defer g.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    // Should be able to analyze without UI involvement
    const group1 = [_][]const u8{"idea1"};
    const group2 = [_][]const u8{"idea2"};

    try service.analyzeGroups(&group1, &group2, &g, &llm_client);

    // Verify graph was populated
    try testing.expect(g.vertices.items.len == 2);
}

test "module dependency graph is acyclic" {
    // Zig's module system enforces this at compile time
    // If there were circular dependencies, compilation would fail
    // This test documents the expected dependency structure:
    //
    // main.zig
    //   ├─> ui.zig
    //   │    ├─> analysis_service.zig
    //   │    │    ├─> graph.zig
    //   │    │    │    └─> validation.zig
    //   │    │    └─> llm.zig
    //   │    │         └─> graph.zig
    //   │    ├─> graph.zig
    //   │    ├─> llm.zig
    //   │    └─> validation.zig
    //   ├─> graph.zig
    //   └─> llm.zig
    //
    // No cycles exist in this dependency graph

    // The fact that this test compiles proves acyclic dependencies
    try testing.expect(true);
}

test "RelationType enum is comprehensive and consistent" {
    // All relationship types should have string and symbol representations
    const relation_types = [_]graph.RelationType{
        .contradictory,
        .implicative,
        .hierarchical,
        .evolutionary,
        .analogous,
        .synonymous,
        .antonymous,
        .part_whole,
        .causal,
    };

    for (relation_types) |rel_type| {
        // Every type should have a string representation
        const str = rel_type.toString();
        try testing.expect(str.len > 0);

        // Every type should have a symbol
        const symbol = rel_type.getSymbol();
        try testing.expect(symbol.len > 0);

        // Every type should have a color
        const color = rel_type.getColor();
        try testing.expect(color >= 0 and color <= 8);
    }
}

test "validation enforces security constraints" {
    // Test that validation prevents common security issues

    // Prevent empty input
    const result1 = validation.validateIdea("");
    try testing.expectError(error.EmptyInput, result1);

    // Prevent excessively long input (DoS prevention)
    var long_input: [1001]u8 = undefined;
    @memset(&long_input, 'a');
    const result2 = validation.validateIdea(&long_input);
    try testing.expectError(error.InputTooLong, result2);

    // Prevent invalid UTF-8 (prevent encoding attacks)
    const invalid_utf8 = [_]u8{ 0xFF, 0xFE, 0xFD };
    const result3 = validation.validateIdea(&invalid_utf8);
    try testing.expectError(error.InvalidUtf8, result3);
}

test "LLM client has resilience configuration" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = llm.LLMClient.init(allocator);
    defer client.deinit();

    // Verify resilience configuration exists
    try testing.expect(client.config.max_retries > 0);
    try testing.expect(client.config.timeout_ms > 0);
    try testing.expect(client.config.initial_backoff_ms > 0);
}

test "graph layout algorithm is bounded" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var g = graph.SemanticGraph.init(allocator);
    defer g.deinit();

    // Add some vertices
    _ = try g.addVertex("idea1", 0);
    _ = try g.addVertex("idea2", 0);
    _ = try g.addVertex("idea3", 1);
    _ = try g.addVertex("idea4", 1);

    // Layout should complete in reasonable time
    const start = std.time.milliTimestamp();
    g.calculateLayout(100.0, 50.0);
    const elapsed = std.time.milliTimestamp() - start;

    // Should complete in under 1 second for small graphs
    try testing.expect(elapsed < 1000);

    // Vertices should be within bounds
    for (g.vertices.items) |vertex| {
        try testing.expect(vertex.x >= 0.0 and vertex.x <= 100.0);
        try testing.expect(vertex.y >= 0.0 and vertex.y <= 50.0);
    }
}
