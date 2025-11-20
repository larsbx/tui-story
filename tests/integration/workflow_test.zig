const std = @import("std");
const testing = std.testing;

// Import application modules
const graph = @import("../../src/graph.zig");
const llm = @import("../../src/llm.zig");
const analysis_service = @import("../../src/analysis_service.zig");
const validation = @import("../../src/validation.zig");

// Integration tests verify that modules work together correctly

test "incremental idea addition workflow with mock LLM" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok);
    }
    const allocator = gpa.allocator();

    // Setup: Create test ideas
    const ideas = [_][]const u8{
        "Democracy",
        "Representative government",
        "Citizen participation",
        "Authoritarianism",
        "Centralized control",
        "Limited freedoms",
    };

    // Initialize services
    var service = analysis_service.AnalysisService.init(allocator);
    var semantic_graph = graph.SemanticGraph.init(allocator);
    defer semantic_graph.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    // Track all ideas added so far
    var ideas_list = std.ArrayList([]const u8).init(allocator);
    defer ideas_list.deinit();

    // Execute: Add ideas one at a time
    for (ideas) |new_idea| {
        // Analyze against all existing ideas
        try service.analyzeNewIdea(new_idea, ideas_list.items, &semantic_graph, &llm_client);
        try ideas_list.append(new_idea);

        // Verify the graph grows with each addition
        try testing.expect(semantic_graph.vertices.items.len == ideas_list.items.len);
    }

    // Verify: Graph should be fully populated
    try testing.expect(semantic_graph.vertices.items.len == 6);

    // Verify: Vertices have correct content
    var found_democracy = false;
    for (semantic_graph.vertices.items) |vertex| {
        if (std.mem.eql(u8, vertex.content, "Democracy")) {
            found_democracy = true;
            try testing.expect(vertex.group == 0);
        }
    }
    try testing.expect(found_democracy);

    // Verify: Edges have valid relationships
    for (semantic_graph.edges.items) |edge| {
        try testing.expect(edge.certainty >= 0.0 and edge.certainty <= 1.0);
        try testing.expect(edge.description.len > 0);

        // Verify vertices exist
        const from_vertex = semantic_graph.getVertex(edge.from);
        const to_vertex = semantic_graph.getVertex(edge.to);
        try testing.expect(from_vertex != null);
        try testing.expect(to_vertex != null);
    }
}

test "workflow handles validation errors gracefully" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok);
    }
    const allocator = gpa.allocator();

    var service = analysis_service.AnalysisService.init(allocator);
    var semantic_graph = graph.SemanticGraph.init(allocator);
    defer semantic_graph.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    // Test with empty idea (should fail validation)
    const existing_ideas = [_][]const u8{};

    const result = service.analyzeNewIdea("", &existing_ideas, &semantic_graph, &llm_client);
    try testing.expectError(error.EmptyContent, result);

    // Graph should remain empty
    try testing.expect(semantic_graph.vertices.items.len == 0);
}

test "workflow with two ideas" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok);
    }
    const allocator = gpa.allocator();

    var service = analysis_service.AnalysisService.init(allocator);
    var semantic_graph = graph.SemanticGraph.init(allocator);
    defer semantic_graph.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    // Add first idea
    const existing_ideas = [_][]const u8{};
    try service.analyzeNewIdea("Idea A", &existing_ideas, &semantic_graph, &llm_client);

    // Should have exactly 1 vertex
    try testing.expect(semantic_graph.vertices.items.len == 1);

    // Add second idea
    const ideas_so_far = [_][]const u8{"Idea A"};
    try service.analyzeNewIdea("Idea B", &ideas_so_far, &semantic_graph, &llm_client);

    // Should have exactly 2 vertices
    try testing.expect(semantic_graph.vertices.items.len == 2);

    // Should have at least 1 relationship
    try testing.expect(semantic_graph.edges.items.len >= 1);
}

test "workflow with many ideas" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok);
    }
    const allocator = gpa.allocator();

    var service = analysis_service.AnalysisService.init(allocator);
    var semantic_graph = graph.SemanticGraph.init(allocator);
    defer semantic_graph.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    // Create 20 ideas
    var ideas_list = std.ArrayList([]const u8).init(allocator);
    defer ideas_list.deinit();

    var all_ideas = std.ArrayList([]const u8).init(allocator);
    defer {
        for (all_ideas.items) |idea| allocator.free(idea);
        all_ideas.deinit();
    }

    var i: usize = 0;
    while (i < 20) : (i += 1) {
        const idea = try std.fmt.allocPrint(allocator, "Idea {}", .{i});
        try all_ideas.append(idea);
    }

    // Add ideas incrementally
    for (all_ideas.items) |new_idea| {
        try service.analyzeNewIdea(new_idea, ideas_list.items, &semantic_graph, &llm_client);
        try ideas_list.append(new_idea);
    }

    // Should have all 20 vertices
    try testing.expect(semantic_graph.vertices.items.len == 20);

    // Verify layout calculation doesn't crash with many vertices
    semantic_graph.calculateLayout(100.0, 50.0);

    // All vertices should be within bounds
    for (semantic_graph.vertices.items) |vertex| {
        try testing.expect(vertex.x >= 0.0 and vertex.x <= 100.0);
        try testing.expect(vertex.y >= 0.0 and vertex.y <= 50.0);
    }
}

test "graph can be cleared and reused" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok);
    }
    const allocator = gpa.allocator();

    var service = analysis_service.AnalysisService.init(allocator);
    var semantic_graph = graph.SemanticGraph.init(allocator);
    defer semantic_graph.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    const existing = [_][]const u8{};

    // First analysis
    try service.analyzeNewIdea("First", &existing, &semantic_graph, &llm_client);
    const first = [_][]const u8{"First"};
    try service.analyzeNewIdea("Second", &first, &semantic_graph, &llm_client);

    const first_vertex_count = semantic_graph.vertices.items.len;

    try testing.expect(first_vertex_count == 2);

    // Clear graph
    semantic_graph.clear();
    try testing.expect(semantic_graph.vertices.items.len == 0);

    // Add new ideas
    try service.analyzeNewIdea("Third", &existing, &semantic_graph, &llm_client);
    const third = [_][]const u8{"Third"};
    try service.analyzeNewIdea("Fourth", &third, &semantic_graph, &llm_client);

    // Should have new data
    try testing.expect(semantic_graph.vertices.items.len == 2);

    // Verify new content
    var found_third = false;
    for (semantic_graph.vertices.items) |vertex| {
        if (std.mem.eql(u8, vertex.content, "Third")) {
            found_third = true;
        }
    }
    try testing.expect(found_third);
}

test "relationship types are preserved through workflow" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok);
    }
    const allocator = gpa.allocator();

    var service = analysis_service.AnalysisService.init(allocator);
    var semantic_graph = graph.SemanticGraph.init(allocator);
    defer semantic_graph.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    const ideas = [_][]const u8{ "A", "B", "C", "X", "Y", "Z" };

    var ideas_list = std.ArrayList([]const u8).init(allocator);
    defer ideas_list.deinit();

    for (ideas) |new_idea| {
        try service.analyzeNewIdea(new_idea, ideas_list.items, &semantic_graph, &llm_client);
        try ideas_list.append(new_idea);
    }

    // Verify that all relationship types are valid
    for (semantic_graph.edges.items) |edge| {
        // Each relationship type should have valid string and symbol
        const type_str = edge.relation_type.toString();
        const symbol = edge.relation_type.getSymbol();
        const color = edge.relation_type.getColor();

        try testing.expect(type_str.len > 0);
        try testing.expect(symbol.len > 0);
        try testing.expect(color <= 8);
    }
}
