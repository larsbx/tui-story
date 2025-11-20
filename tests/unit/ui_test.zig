const std = @import("std");
const testing = std.testing;
const ui = @import("ui");

// ============================================================================
// UIMode Tests
// ============================================================================

test "UIMode enum has all expected modes" {
    // This test ensures all modes are defined and accessible
    const modes = [_]ui.UIMode{
        .help,
        .input,
        .analyzing,
        .viewing_graph,
    };

    // Just verify we can create all mode values
    for (modes) |mode| {
        _ = mode;
    }
}

// ============================================================================
// UIState Initialization Tests
// ============================================================================

test "UIState.initWithAllocator initializes with help mode" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var state = ui.UIState.initWithAllocator(allocator);
    defer {
        // Clean up
        for (state.ideas.items) |idea| {
            allocator.free(idea);
        }
        state.ideas.deinit();
        state.current_input.deinit();
    }

    try testing.expect(state.mode == .help);
    try testing.expect(state.ideas.items.len == 0);
    try testing.expect(state.current_input.items.len == 0);
    try testing.expect(state.selected_edge == null);
    try testing.expect(state.error_message == null);
}

test "UIState.initWithAllocator creates empty idea list" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var state = ui.UIState.initWithAllocator(allocator);
    defer {
        state.ideas.deinit();
        state.current_input.deinit();
    }

    try testing.expect(state.ideas.items.len == 0);
}

test "UIState.initWithAllocator creates empty input buffer" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var state = ui.UIState.initWithAllocator(allocator);
    defer {
        state.ideas.deinit();
        state.current_input.deinit();
    }

    try testing.expect(state.current_input.items.len == 0);
}

// ============================================================================
// Memory Safety Tests
// ============================================================================

test "UIState properly manages memory for idea list" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var state = ui.UIState.initWithAllocator(allocator);

    // Add some ideas
    const idea1 = try allocator.dupe(u8, "test idea 1");
    const idea2 = try allocator.dupe(u8, "test idea 2");
    const idea3 = try allocator.dupe(u8, "test idea 3");

    try state.ideas.append(idea1);
    try state.ideas.append(idea2);
    try state.ideas.append(idea3);

    // Clean up properly
    for (state.ideas.items) |idea| {
        allocator.free(idea);
    }
    state.ideas.deinit();
    state.current_input.deinit();

    // Test passes if no memory leaks detected
}

test "UIState current_input buffer can be cleared" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var state = ui.UIState.initWithAllocator(allocator);
    defer {
        state.ideas.deinit();
        state.current_input.deinit();
    }

    // Add some input
    try state.current_input.appendSlice("test input");
    try testing.expect(state.current_input.items.len > 0);

    // Clear it
    state.current_input.clearRetainingCapacity();
    try testing.expect(state.current_input.items.len == 0);
}

// ============================================================================
// Mode Transition Logic Tests (without vaxis dependency)
// ============================================================================

test "UIState mode can be changed programmatically" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var state = ui.UIState.initWithAllocator(allocator);
    defer {
        state.ideas.deinit();
        state.current_input.deinit();
    }

    // Test mode transitions
    try testing.expect(state.mode == .help);

    state.mode = .input;
    try testing.expect(state.mode == .input);

    state.mode = .analyzing;
    try testing.expect(state.mode == .analyzing);

    state.mode = .viewing_graph;
    try testing.expect(state.mode == .viewing_graph);

    state.mode = .help;
    try testing.expect(state.mode == .help);
}

test "UIState selected_edge can be set and cleared" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var state = ui.UIState.initWithAllocator(allocator);
    defer {
        state.ideas.deinit();
        state.current_input.deinit();
    }

    // Initially null
    try testing.expect(state.selected_edge == null);

    // Can be set
    state.selected_edge = 5;
    try testing.expect(state.selected_edge != null);
    try testing.expect(state.selected_edge.? == 5);

    // Can be changed
    state.selected_edge = 10;
    try testing.expect(state.selected_edge.? == 10);

    // Can be cleared
    state.selected_edge = null;
    try testing.expect(state.selected_edge == null);
}

test "UIState error_message can be set and cleared" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var state = ui.UIState.initWithAllocator(allocator);
    defer {
        state.ideas.deinit();
        state.current_input.deinit();
    }

    // Initially null
    try testing.expect(state.error_message == null);

    // Can be set
    state.error_message = "Test error";
    try testing.expect(state.error_message != null);
    try testing.expectEqualStrings("Test error", state.error_message.?);

    // Can be cleared
    state.error_message = null;
    try testing.expect(state.error_message == null);
}

// ============================================================================
// Idea Management Tests
// ============================================================================

test "UIState can store ideas" {
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

    const idea = try allocator.dupe(u8, "test idea");
    try state.ideas.append(idea);

    try testing.expect(state.ideas.items.len == 1);
    try testing.expectEqualStrings("test idea", state.ideas.items[0]);
}

test "UIState can store multiple ideas" {
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

    const idea1 = try allocator.dupe(u8, "first idea");
    const idea2 = try allocator.dupe(u8, "second idea");
    try state.ideas.append(idea1);
    try state.ideas.append(idea2);

    try testing.expect(state.ideas.items.len == 2);
    try testing.expectEqualStrings("first idea", state.ideas.items[0]);
    try testing.expectEqualStrings("second idea", state.ideas.items[1]);
}

test "UIState can store many ideas incrementally" {
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

    // Add multiple ideas incrementally
    try state.ideas.append(try allocator.dupe(u8, "idea 1"));
    try state.ideas.append(try allocator.dupe(u8, "idea 2"));
    try state.ideas.append(try allocator.dupe(u8, "idea 3"));
    try state.ideas.append(try allocator.dupe(u8, "idea 4"));
    try state.ideas.append(try allocator.dupe(u8, "idea 5"));

    try testing.expect(state.ideas.items.len == 5);
    try testing.expectEqualStrings("idea 1", state.ideas.items[0]);
    try testing.expectEqualStrings("idea 5", state.ideas.items[4]);
}

// ============================================================================
// Input Buffer Tests
// ============================================================================

test "UIState current_input can accumulate characters" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var state = ui.UIState.initWithAllocator(allocator);
    defer {
        state.ideas.deinit();
        state.current_input.deinit();
    }

    try state.current_input.append('h');
    try state.current_input.append('e');
    try state.current_input.append('l');
    try state.current_input.append('l');
    try state.current_input.append('o');

    try testing.expect(state.current_input.items.len == 5);
    try testing.expectEqualStrings("hello", state.current_input.items);
}

test "UIState current_input can be converted to owned string" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var state = ui.UIState.initWithAllocator(allocator);
    defer {
        state.ideas.deinit();
        state.current_input.deinit();
    }

    try state.current_input.appendSlice("test string");

    const owned = try allocator.dupe(u8, state.current_input.items);
    defer allocator.free(owned);

    try testing.expectEqualStrings("test string", owned);
}

// ============================================================================
// State Validation Tests
// ============================================================================

test "UIState supports incremental idea addition" {
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

    // Empty state - first idea doesn't need analysis
    const needs_analysis_when_empty = state.ideas.items.len > 0;
    try testing.expect(!needs_analysis_when_empty);

    // Add first idea - no analysis needed yet
    try state.ideas.append(try allocator.dupe(u8, "idea 1"));
    try testing.expect(state.ideas.items.len == 1);

    // With existing ideas - new ideas need analysis
    const needs_analysis_with_ideas = state.ideas.items.len > 0;
    try testing.expect(needs_analysis_with_ideas);

    // Can add more ideas incrementally
    try state.ideas.append(try allocator.dupe(u8, "idea 2"));
    try state.ideas.append(try allocator.dupe(u8, "idea 3"));
    try testing.expect(state.ideas.items.len == 3);
}
