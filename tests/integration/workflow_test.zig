const std = @import("std");
const testing = std.testing;

// Import application modules
const graph = @import("../../src/graph.zig");
const llm = @import("../../src/llm.zig");
const analysis_service = @import("../../src/analysis_service.zig");
const validation = @import("../../src/validation.zig");

// Integration tests verify that modules work together correctly

test "complete analysis workflow with mock LLM" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok);
    }
    const allocator = gpa.allocator();

    // Setup: Create test ideas
    const group1 = [_][]const u8{
        "Democracy",
        "Representative government",
        "Citizen participation",
    };

    const group2 = [_][]const u8{
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

    // Execute: Run complete analysis workflow
    try service.analyzeGroups(&group1, &group2, &semantic_graph, &llm_client);

    // Verify: Graph should be populated
    try testing.expect(semantic_graph.vertices.items.len == 6);
    try testing.expect(semantic_graph.edges.items.len > 0);

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
    const group1_invalid = [_][]const u8{""};
    const group2 = [_][]const u8{"test"};

    const result = service.analyzeGroups(&group1_invalid, &group2, &semantic_graph, &llm_client);
    try testing.expectError(error.EmptyContent, result);

    // Graph should remain empty
    try testing.expect(semantic_graph.vertices.items.len == 0);
}

test "workflow with single idea in each group" {
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

    const group1 = [_][]const u8{"Idea A"};
    const group2 = [_][]const u8{"Idea B"};

    try service.analyzeGroups(&group1, &group2, &semantic_graph, &llm_client);

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

    // Create 10 ideas in each group
    var group1_list = std.ArrayList([]const u8).init(allocator);
    defer group1_list.deinit();
    var group2_list = std.ArrayList([]const u8).init(allocator);
    defer group2_list.deinit();

    var i: usize = 0;
    while (i < 10) : (i += 1) {
        const idea1 = try std.fmt.allocPrint(allocator, "Group1 Idea {}", .{i});
        const idea2 = try std.fmt.allocPrint(allocator, "Group2 Idea {}", .{i});
        try group1_list.append(idea1);
        try group2_list.append(idea2);
    }
    defer {
        for (group1_list.items) |idea| allocator.free(idea);
        for (group2_list.items) |idea| allocator.free(idea);
    }

    // Run analysis
    try service.analyzeGroups(
        group1_list.items,
        group2_list.items,
        &semantic_graph,
        &llm_client,
    );

    // Should have all 20 vertices
    try testing.expect(semantic_graph.vertices.items.len == 20);

    // Should have multiple relationships
    try testing.expect(semantic_graph.edges.items.len > 0);

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

    const group1 = [_][]const u8{"First"};
    const group2 = [_][]const u8{"Second"};

    // First analysis
    try service.analyzeGroups(&group1, &group2, &semantic_graph, &llm_client);
    const first_vertex_count = semantic_graph.vertices.items.len;
    const first_edge_count = semantic_graph.edges.items.len;

    try testing.expect(first_vertex_count > 0);
    try testing.expect(first_edge_count > 0);

    // Clear and run second analysis
    const group3 = [_][]const u8{"Third"};
    const group4 = [_][]const u8{"Fourth"};

    try service.analyzeGroups(&group3, &group4, &semantic_graph, &llm_client);

    // Should have new data
    try testing.expect(semantic_graph.vertices.items.len == 2);
    try testing.expect(semantic_graph.edges.items.len > 0);

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

    const group1 = [_][]const u8{ "A", "B", "C" };
    const group2 = [_][]const u8{ "X", "Y", "Z" };

    try service.analyzeGroups(&group1, &group2, &semantic_graph, &llm_client);

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
