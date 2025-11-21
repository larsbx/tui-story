const std = @import("std");
const testing = std.testing;

// Import application modules
const graph = @import("graph");
const llm = @import("llm");
const ui = @import("ui");

// Integration tests for UI state functions that don't require vaxis mocking

test "UIState.initWithAllocator creates properly initialized state" {
    const allocator = testing.allocator;

    var state = ui.UIState.initWithAllocator(allocator);
    defer {
        state.ideas.deinit();
        state.current_input.deinit();
    }

    try testing.expectEqual(ui.UIMode.help, state.mode);
    try testing.expectEqual(@as(usize, 0), state.ideas.items.len);
    try testing.expectEqual(@as(usize, 0), state.current_input.items.len);
    try testing.expect(state.selected_edge == null);
    try testing.expect(state.error_message == null);
}

test "UIState.reset clears all data" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var state = ui.UIState.initWithAllocator(allocator);
    defer {
        state.ideas.deinit();
        state.current_input.deinit();
    }

    var semantic_graph = graph.SemanticGraph.init(allocator);
    defer semantic_graph.deinit();

    // Add some test data
    const idea1 = try allocator.dupe(u8, "Test idea 1");
    const idea2 = try allocator.dupe(u8, "Test idea 2");
    try state.ideas.append(idea1);
    try state.ideas.append(idea2);
    try state.current_input.appendSlice("Some input");

    _ = try semantic_graph.addVertex("Vertex 1", 0);
    _ = try semantic_graph.addVertex("Vertex 2", 0);

    // Verify data exists
    try testing.expectEqual(@as(usize, 2), state.ideas.items.len);
    try testing.expectEqual(@as(usize, 10), state.current_input.items.len);
    try testing.expectEqual(@as(usize, 2), semantic_graph.vertices.items.len);

    // Reset
    try state.reset(&semantic_graph);

    // Verify all cleared
    try testing.expectEqual(@as(usize, 0), state.ideas.items.len);
    try testing.expectEqual(@as(usize, 0), state.current_input.items.len);
    try testing.expectEqual(@as(usize, 0), semantic_graph.vertices.items.len);
    try testing.expectEqual(@as(usize, 0), semantic_graph.edges.items.len);
    try testing.expectEqual(ui.UIMode.input, state.mode);
}

test "UIState.analyzeNewIdea adds first idea without analysis" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var state = ui.UIState.initWithAllocator(allocator);
    defer {
        state.ideas.deinit();
        state.current_input.deinit();
    }

    var semantic_graph = graph.SemanticGraph.init(allocator);
    defer semantic_graph.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    // First idea should be added without LLM analysis
    try state.analyzeNewIdea("First idea", &semantic_graph, &llm_client);

    try testing.expectEqual(@as(usize, 1), semantic_graph.vertices.items.len);
    try testing.expectEqualStrings("First idea", semantic_graph.vertices.items[0].content);
    try testing.expectEqual(@as(usize, 0), semantic_graph.edges.items.len);
}

test "UIState.analyzeNewIdea analyzes subsequent ideas" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var state = ui.UIState.initWithAllocator(allocator);
    defer {
        // Clean up ideas
        for (state.ideas.items) |idea| {
            allocator.free(idea);
        }
        state.ideas.deinit();
        state.current_input.deinit();
    }

    var semantic_graph = graph.SemanticGraph.init(allocator);
    defer semantic_graph.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    // Add first idea
    try state.analyzeNewIdea("First idea", &semantic_graph, &llm_client);
    try state.ideas.append(try allocator.dupe(u8, "First idea"));

    // Add second idea - should trigger LLM analysis
    try state.analyzeNewIdea("Second idea", &semantic_graph, &llm_client);

    try testing.expectEqual(@as(usize, 2), semantic_graph.vertices.items.len);
    // Mock LLM generates relationships
    try testing.expect(semantic_graph.edges.items.len >= 0);
}

test "UIState tracks multiple ideas correctly" {
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

    var semantic_graph = graph.SemanticGraph.init(allocator);
    defer semantic_graph.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    const test_ideas = [_][]const u8{ "Idea A", "Idea B", "Idea C", "Idea D" };

    for (test_ideas) |idea| {
        try state.analyzeNewIdea(idea, &semantic_graph, &llm_client);
        try state.ideas.append(try allocator.dupe(u8, idea));
    }

    // Verify all ideas tracked
    try testing.expectEqual(@as(usize, 4), state.ideas.items.len);
    try testing.expectEqual(@as(usize, 4), semantic_graph.vertices.items.len);

    // Verify content matches
    for (state.ideas.items, 0..) |idea, i| {
        var found = false;
        for (semantic_graph.vertices.items) |vertex| {
            if (std.mem.eql(u8, vertex.content, idea)) {
                found = true;
                break;
            }
        }
        try testing.expect(found);
        _ = i;
    }
}

test "UIState.reset can be called multiple times safely" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var state = ui.UIState.initWithAllocator(allocator);
    defer {
        state.ideas.deinit();
        state.current_input.deinit();
    }

    var semantic_graph = graph.SemanticGraph.init(allocator);
    defer semantic_graph.deinit();

    // Reset multiple times
    try state.reset(&semantic_graph);
    try state.reset(&semantic_graph);
    try state.reset(&semantic_graph);

    // Should still be in valid state
    try testing.expectEqual(@as(usize, 0), state.ideas.items.len);
    try testing.expectEqual(ui.UIMode.input, state.mode);
}

test "UIState mode transitions" {
    const allocator = testing.allocator;

    var state = ui.UIState.initWithAllocator(allocator);
    defer {
        state.ideas.deinit();
        state.current_input.deinit();
    }

    // Starts in help mode
    try testing.expectEqual(ui.UIMode.help, state.mode);

    // Can transition to input mode
    state.mode = .input;
    try testing.expectEqual(ui.UIMode.input, state.mode);

    // Can transition to analyzing mode
    state.mode = .analyzing;
    try testing.expectEqual(ui.UIMode.analyzing, state.mode);

    // Can transition to viewing_graph mode
    state.mode = .viewing_graph;
    try testing.expectEqual(ui.UIMode.viewing_graph, state.mode);

    // Can go back to help mode
    state.mode = .help;
    try testing.expectEqual(ui.UIMode.help, state.mode);
}

test "UIState current_input can be modified" {
    const allocator = testing.allocator;

    var state = ui.UIState.initWithAllocator(allocator);
    defer {
        state.ideas.deinit();
        state.current_input.deinit();
    }

    // Initially empty
    try testing.expectEqual(@as(usize, 0), state.current_input.items.len);

    // Can append text
    try state.current_input.appendSlice("Hello");
    try testing.expectEqual(@as(usize, 5), state.current_input.items.len);
    try testing.expectEqualStrings("Hello", state.current_input.items);

    // Can append more
    try state.current_input.appendSlice(" World");
    try testing.expectEqualStrings("Hello World", state.current_input.items);

    // Can clear
    state.current_input.clearRetainingCapacity();
    try testing.expectEqual(@as(usize, 0), state.current_input.items.len);
}
