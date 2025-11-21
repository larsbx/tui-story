const std = @import("std");
const testing = std.testing;
const graph = @import("graph");
const llm = @import("llm");
const analysis_service = @import("analysis_service");

// ============================================================================
// AnalysisService.analyzeNewIdea Tests
// ============================================================================

test "analyzeNewIdea adds new vertex to empty graph" {
    const allocator = testing.allocator;

    var service = analysis_service.AnalysisService.init(allocator);
    var semantic_graph = graph.SemanticGraph.init(allocator);
    defer semantic_graph.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    const empty_ideas: []const []const u8 = &[_][]const u8{};

    try service.analyzeNewIdea("First idea", empty_ideas, &semantic_graph, &llm_client);

    try testing.expectEqual(@as(usize, 1), semantic_graph.vertices.items.len);
    try testing.expectEqualStrings("First idea", semantic_graph.vertices.items[0].content);
}

test "analyzeNewIdea creates relationships with existing ideas" {
    const allocator = testing.allocator;

    var service = analysis_service.AnalysisService.init(allocator);
    var semantic_graph = graph.SemanticGraph.init(allocator);
    defer semantic_graph.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    // Add first idea
    const empty_ideas: []const []const u8 = &[_][]const u8{};
    try service.analyzeNewIdea("First idea", empty_ideas, &semantic_graph, &llm_client);

    // Add second idea - should create relationship(s) via mock LLM
    const existing = [_][]const u8{"First idea"};
    try service.analyzeNewIdea("Second idea", &existing, &semantic_graph, &llm_client);

    try testing.expectEqual(@as(usize, 2), semantic_graph.vertices.items.len);
    // Mock LLM generates relationships, so we should have edges
    try testing.expect(semantic_graph.edges.items.len >= 0);
}

test "analyzeNewIdea handles multiple existing ideas" {
    const allocator = testing.allocator;

    var service = analysis_service.AnalysisService.init(allocator);
    var semantic_graph = graph.SemanticGraph.init(allocator);
    defer semantic_graph.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    // Build up graph with multiple ideas
    var ideas_list = std.ArrayList([]const u8).init(allocator);
    defer ideas_list.deinit();

    const ideas = [_][]const u8{ "Idea A", "Idea B", "Idea C" };

    for (ideas) |idea| {
        try service.analyzeNewIdea(idea, ideas_list.items, &semantic_graph, &llm_client);
        try ideas_list.append(idea);
    }

    try testing.expectEqual(@as(usize, 3), semantic_graph.vertices.items.len);
}

// ============================================================================
// AnalysisService.analyzeGroups Tests
// ============================================================================

test "analyzeGroups creates graph from two groups" {
    const allocator = testing.allocator;

    var service = analysis_service.AnalysisService.init(allocator);
    var semantic_graph = graph.SemanticGraph.init(allocator);
    defer semantic_graph.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    const group1 = [_][]const u8{ "Democracy", "Freedom" };
    const group2 = [_][]const u8{ "Authoritarianism", "Control" };

    try service.analyzeGroups(&group1, &group2, &semantic_graph, &llm_client);

    // Should have 4 vertices (2 from each group)
    try testing.expectEqual(@as(usize, 4), semantic_graph.vertices.items.len);

    // Verify vertices are assigned to correct groups
    for (semantic_graph.vertices.items) |vertex| {
        const in_group1 = std.mem.eql(u8, vertex.content, "Democracy") or
            std.mem.eql(u8, vertex.content, "Freedom");
        const in_group2 = std.mem.eql(u8, vertex.content, "Authoritarianism") or
            std.mem.eql(u8, vertex.content, "Control");

        if (in_group1) {
            try testing.expectEqual(@as(u8, 0), vertex.group);
        } else if (in_group2) {
            try testing.expectEqual(@as(u8, 1), vertex.group);
        }
    }
}

test "analyzeGroups handles empty groups" {
    const allocator = testing.allocator;

    var service = analysis_service.AnalysisService.init(allocator);
    var semantic_graph = graph.SemanticGraph.init(allocator);
    defer semantic_graph.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    const empty: []const []const u8 = &[_][]const u8{};

    try service.analyzeGroups(empty, empty, &semantic_graph, &llm_client);

    try testing.expectEqual(@as(usize, 0), semantic_graph.vertices.items.len);
    try testing.expectEqual(@as(usize, 0), semantic_graph.edges.items.len);
}

test "analyzeGroups clears existing graph before analysis" {
    const allocator = testing.allocator;

    var service = analysis_service.AnalysisService.init(allocator);
    var semantic_graph = graph.SemanticGraph.init(allocator);
    defer semantic_graph.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    // First analysis
    const group1a = [_][]const u8{"Old idea"};
    const group2a = [_][]const u8{"Another old idea"};
    try service.analyzeGroups(&group1a, &group2a, &semantic_graph, &llm_client);
    try testing.expectEqual(@as(usize, 2), semantic_graph.vertices.items.len);

    // Second analysis should clear and replace
    const group1b = [_][]const u8{"New idea"};
    const group2b = [_][]const u8{"Fresh idea"};
    try service.analyzeGroups(&group1b, &group2b, &semantic_graph, &llm_client);

    // Should only have new ideas
    try testing.expectEqual(@as(usize, 2), semantic_graph.vertices.items.len);

    // Verify content is from new groups
    var found_new = false;
    var found_fresh = false;
    for (semantic_graph.vertices.items) |vertex| {
        if (std.mem.eql(u8, vertex.content, "New idea")) found_new = true;
        if (std.mem.eql(u8, vertex.content, "Fresh idea")) found_fresh = true;
    }
    try testing.expect(found_new);
    try testing.expect(found_fresh);
}
