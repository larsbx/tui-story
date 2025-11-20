const std = @import("std");
const testing = std.testing;
const graph = @import("../../src/graph.zig");

// ============================================================================
// RelationType Tests
// ============================================================================

test "RelationType.toString returns correct strings for all variants" {
    try testing.expectEqualStrings("IMPLICATIVE", graph.RelationType.implicative.toString());
    try testing.expectEqualStrings("HIERARCHICAL", graph.RelationType.hierarchical.toString());
    try testing.expectEqualStrings("CONTRADICTORY", graph.RelationType.contradictory.toString());
    try testing.expectEqualStrings("EVOLUTIONARY", graph.RelationType.evolutionary.toString());
    try testing.expectEqualStrings("ANALOGOUS", graph.RelationType.analogous.toString());
    try testing.expectEqualStrings("SYNONYMOUS", graph.RelationType.synonymous.toString());
    try testing.expectEqualStrings("ANTONYMOUS", graph.RelationType.antonymous.toString());
    try testing.expectEqualStrings("PART_WHOLE", graph.RelationType.part_whole.toString());
    try testing.expectEqualStrings("CAUSAL", graph.RelationType.causal.toString());
}

test "RelationType.getSymbol returns correct symbols for all variants" {
    try testing.expectEqualStrings("⊥", graph.RelationType.contradictory.getSymbol());
    try testing.expectEqualStrings("→", graph.RelationType.implicative.getSymbol());
    try testing.expectEqualStrings("⊆", graph.RelationType.hierarchical.getSymbol());
    try testing.expectEqualStrings("⟿", graph.RelationType.evolutionary.getSymbol());
    try testing.expectEqualStrings("≈", graph.RelationType.analogous.getSymbol());
    try testing.expectEqualStrings("≡", graph.RelationType.synonymous.getSymbol());
    try testing.expectEqualStrings("≠", graph.RelationType.antonymous.getSymbol());
    try testing.expectEqualStrings("∈", graph.RelationType.part_whole.getSymbol());
    try testing.expectEqualStrings("⇒", graph.RelationType.causal.getSymbol());
}

test "RelationType.getColor returns valid color codes" {
    // All colors should be in valid ANSI color range (0-255)
    // Basic colors are 0-7, we're using 1-6
    const colors = [_]graph.RelationType{
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

    for (colors) |rel_type| {
        const color = rel_type.getColor();
        try testing.expect(color >= 1);
        try testing.expect(color <= 6);
    }
}

// ============================================================================
// SemanticGraph - Vertex Management Tests
// ============================================================================

test "addVertex stores content and returns unique ID" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok);
    }
    const allocator = gpa.allocator();

    var g = graph.SemanticGraph.init(allocator);
    defer g.deinit();

    const id = try g.addVertex("test content", 0);
    try testing.expect(id == 0);

    const vertex = g.getVertex(id);
    try testing.expect(vertex != null);
    try testing.expectEqualStrings("test content", vertex.?.content);
    try testing.expect(vertex.?.group == 0);
}

test "addVertex returns sequential unique IDs" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok);
    }
    const allocator = gpa.allocator();

    var g = graph.SemanticGraph.init(allocator);
    defer g.deinit();

    const id1 = try g.addVertex("first", 0);
    const id2 = try g.addVertex("second", 1);
    const id3 = try g.addVertex("third", 0);

    try testing.expect(id1 == 0);
    try testing.expect(id2 == 1);
    try testing.expect(id3 == 2);
}

test "getVertex returns null for non-existent ID" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok);
    }
    const allocator = gpa.allocator();

    var g = graph.SemanticGraph.init(allocator);
    defer g.deinit();

    _ = try g.addVertex("test", 0);

    // ID 999 doesn't exist
    const vertex = g.getVertex(999);
    try testing.expect(vertex == null);
}

test "addVertex assigns correct group membership" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok);
    }
    const allocator = gpa.allocator();

    var g = graph.SemanticGraph.init(allocator);
    defer g.deinit();

    const id_group0 = try g.addVertex("group 0 idea", 0);
    const id_group1 = try g.addVertex("group 1 idea", 1);

    const v0 = g.getVertex(id_group0);
    const v1 = g.getVertex(id_group1);

    try testing.expect(v0.?.group == 0);
    try testing.expect(v1.?.group == 1);
}

// ============================================================================
// SemanticGraph - Edge Management Tests
// ============================================================================

test "addEdge creates relationship between vertices" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok);
    }
    const allocator = gpa.allocator();

    var g = graph.SemanticGraph.init(allocator);
    defer g.deinit();

    const id1 = try g.addVertex("idea 1", 0);
    const id2 = try g.addVertex("idea 2", 1);

    try g.addEdge(id1, id2, .implicative, 0.9, "test relationship");

    try testing.expect(g.edges.items.len == 1);
    const edge = g.edges.items[0];
    try testing.expect(edge.from == id1);
    try testing.expect(edge.to == id2);
    try testing.expect(edge.relation_type == .implicative);
    try testing.expect(edge.certainty == 0.9);
    try testing.expectEqualStrings("test relationship", edge.description);
}

test "addEdge stores certainty score correctly" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok);
    }
    const allocator = gpa.allocator();

    var g = graph.SemanticGraph.init(allocator);
    defer g.deinit();

    const id1 = try g.addVertex("idea 1", 0);
    const id2 = try g.addVertex("idea 2", 1);

    try g.addEdge(id1, id2, .analogous, 0.75, "moderate certainty");

    const edge = g.edges.items[0];
    try testing.expect(@abs(edge.certainty - 0.75) < 0.001); // Float comparison with epsilon
}

test "multiple edges can be added to graph" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok);
    }
    const allocator = gpa.allocator();

    var g = graph.SemanticGraph.init(allocator);
    defer g.deinit();

    const id1 = try g.addVertex("idea 1", 0);
    const id2 = try g.addVertex("idea 2", 1);
    const id3 = try g.addVertex("idea 3", 1);

    try g.addEdge(id1, id2, .implicative, 0.9, "first edge");
    try g.addEdge(id1, id3, .hierarchical, 0.8, "second edge");
    try g.addEdge(id2, id3, .causal, 0.7, "third edge");

    try testing.expect(g.edges.items.len == 3);
}

// ============================================================================
// Memory Safety Tests - CRITICAL for Zig
// ============================================================================

test "SemanticGraph.deinit frees all memory without leaking" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok); // Fail if memory leaked
    }
    const allocator = gpa.allocator();

    var g = graph.SemanticGraph.init(allocator);

    _ = try g.addVertex("vertex 1", 0);
    _ = try g.addVertex("vertex 2", 1);
    _ = try g.addVertex("vertex 3", 0);
    try g.addEdge(0, 1, .implicative, 0.9, "test relationship 1");
    try g.addEdge(1, 2, .hierarchical, 0.8, "test relationship 2");

    g.deinit(); // Must not leak
}

test "SemanticGraph.clear frees memory and resets state" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok);
    }
    const allocator = gpa.allocator();

    var g = graph.SemanticGraph.init(allocator);
    defer g.deinit();

    _ = try g.addVertex("vertex 1", 0);
    _ = try g.addVertex("vertex 2", 1);
    try g.addEdge(0, 1, .implicative, 0.9, "test relationship");

    g.clear(); // Must not leak

    // Verify state reset
    try testing.expect(g.vertices.items.len == 0);
    try testing.expect(g.edges.items.len == 0);
    try testing.expect(g.next_id == 0);

    // Verify we can add new vertices after clear
    const new_id = try g.addVertex("new vertex", 0);
    try testing.expect(new_id == 0); // IDs should restart from 0
}

test "empty SemanticGraph can be safely deinitialized" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok);
    }
    const allocator = gpa.allocator();

    var g = graph.SemanticGraph.init(allocator);
    g.deinit(); // Should not crash or leak
}

// ============================================================================
// Layout Algorithm Tests
// ============================================================================

test "calculateLayout handles empty graph" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok);
    }
    const allocator = gpa.allocator();

    var g = graph.SemanticGraph.init(allocator);
    defer g.deinit();

    // Should not crash on empty graph
    g.calculateLayout(100.0, 100.0);
}

test "calculateLayout sets vertex positions within bounds" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok);
    }
    const allocator = gpa.allocator();

    var g = graph.SemanticGraph.init(allocator);
    defer g.deinit();

    _ = try g.addVertex("idea 1", 0);
    _ = try g.addVertex("idea 2", 0);
    _ = try g.addVertex("idea 3", 1);
    _ = try g.addVertex("idea 4", 1);

    const width: f32 = 200.0;
    const height: f32 = 100.0;

    g.calculateLayout(width, height);

    // Verify all vertices are within bounds
    for (g.vertices.items) |vertex| {
        try testing.expect(vertex.x >= 10.0);
        try testing.expect(vertex.x <= width - 10.0);
        try testing.expect(vertex.y >= 5.0);
        try testing.expect(vertex.y <= height - 5.0);
    }
}

test "calculateLayout separates groups horizontally" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok);
    }
    const allocator = gpa.allocator();

    var g = graph.SemanticGraph.init(allocator);
    defer g.deinit();

    const id0 = try g.addVertex("group 0 idea", 0);
    const id1 = try g.addVertex("group 1 idea", 1);

    g.calculateLayout(200.0, 100.0);

    const v0 = g.getVertex(id0).?;
    const v1 = g.getVertex(id1).?;

    // Group 0 should be on the left side (around x = 50)
    // Group 1 should be on the right side (around x = 150)
    try testing.expect(v0.x < 100.0);
    try testing.expect(v1.x > 100.0);
}

test "calculateLayout handles single vertex" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok);
    }
    const allocator = gpa.allocator();

    var g = graph.SemanticGraph.init(allocator);
    defer g.deinit();

    const id = try g.addVertex("single vertex", 0);

    g.calculateLayout(200.0, 100.0);

    const vertex = g.getVertex(id).?;
    try testing.expect(vertex.x >= 10.0 and vertex.x <= 190.0);
    try testing.expect(vertex.y >= 5.0 and vertex.y <= 95.0);
}
