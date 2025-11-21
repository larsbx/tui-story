const std = @import("std");
const testing = std.testing;
const thread_safe_graph = @import("thread_safe_graph");
const graph = @import("graph");

test "ThreadSafeGraph: basic initialization" {
    const allocator = testing.allocator;

    var safe_graph = thread_safe_graph.ThreadSafeGraph.init(allocator);
    defer safe_graph.deinit();

    try testing.expectEqual(@as(usize, 0), safe_graph.getVertexCount());
    try testing.expectEqual(@as(usize, 0), safe_graph.getEdgeCount());
}

test "ThreadSafeGraph: add vertex" {
    const allocator = testing.allocator;

    var safe_graph = thread_safe_graph.ThreadSafeGraph.init(allocator);
    defer safe_graph.deinit();

    const id = try safe_graph.addVertex("Test Vertex");

    try testing.expect(id.len > 0);
    try testing.expectEqual(@as(usize, 1), safe_graph.getVertexCount());
}

test "ThreadSafeGraph: add multiple vertices" {
    const allocator = testing.allocator;

    var safe_graph = thread_safe_graph.ThreadSafeGraph.init(allocator);
    defer safe_graph.deinit();

    _ = try safe_graph.addVertex("Vertex 1");
    _ = try safe_graph.addVertex("Vertex 2");
    _ = try safe_graph.addVertex("Vertex 3");

    try testing.expectEqual(@as(usize, 3), safe_graph.getVertexCount());
}

test "ThreadSafeGraph: add edge" {
    const allocator = testing.allocator;

    var safe_graph = thread_safe_graph.ThreadSafeGraph.init(allocator);
    defer safe_graph.deinit();

    const v1 = try safe_graph.addVertex("Vertex A");
    const v2 = try safe_graph.addVertex("Vertex B");

    try safe_graph.addOrUpdateEdge(v1, v2, .implicative, 0.9);

    try testing.expectEqual(@as(usize, 2), safe_graph.getVertexCount());
    try testing.expectEqual(@as(usize, 1), safe_graph.getEdgeCount());
}

test "ThreadSafeGraph: get vertex" {
    const allocator = testing.allocator;

    var safe_graph = thread_safe_graph.ThreadSafeGraph.init(allocator);
    defer safe_graph.deinit();

    const id = try safe_graph.addVertex("Test Content");
    const vertex = safe_graph.getVertex(id);

    try testing.expect(vertex != null);
    try testing.expectEqualStrings("Test Content", vertex.?.content);
}

test "ThreadSafeGraph: has vertex" {
    const allocator = testing.allocator;

    var safe_graph = thread_safe_graph.ThreadSafeGraph.init(allocator);
    defer safe_graph.deinit();

    const id = try safe_graph.addVertex("Test");

    try testing.expect(safe_graph.hasVertex(id));
    try testing.expect(!safe_graph.hasVertex("nonexistent"));
}

test "ThreadSafeGraph: clear" {
    const allocator = testing.allocator;

    var safe_graph = thread_safe_graph.ThreadSafeGraph.init(allocator);
    defer safe_graph.deinit();

    _ = try safe_graph.addVertex("V1");
    _ = try safe_graph.addVertex("V2");

    try testing.expectEqual(@as(usize, 2), safe_graph.getVertexCount());

    safe_graph.clear();

    try testing.expectEqual(@as(usize, 0), safe_graph.getVertexCount());
}

test "ThreadSafeGraph: vertices snapshot" {
    const allocator = testing.allocator;

    var safe_graph = thread_safe_graph.ThreadSafeGraph.init(allocator);
    defer safe_graph.deinit();

    _ = try safe_graph.addVertex("V1");
    _ = try safe_graph.addVertex("V2");
    _ = try safe_graph.addVertex("V3");

    const snapshot = try safe_graph.getVerticesSnapshot();
    defer allocator.free(snapshot);

    try testing.expectEqual(@as(usize, 3), snapshot.len);
}

test "ThreadSafeGraph: edges snapshot" {
    const allocator = testing.allocator;

    var safe_graph = thread_safe_graph.ThreadSafeGraph.init(allocator);
    defer safe_graph.deinit();

    const v1 = try safe_graph.addVertex("A");
    const v2 = try safe_graph.addVertex("B");
    const v3 = try safe_graph.addVertex("C");

    try safe_graph.addOrUpdateEdge(v1, v2, .implicative, 0.8);
    try safe_graph.addOrUpdateEdge(v2, v3, .hierarchical, 0.9);

    const snapshot = try safe_graph.getEdgesSnapshot();
    defer allocator.free(snapshot);

    try testing.expectEqual(@as(usize, 2), snapshot.len);
}

test "ThreadSafeGraph: concurrent vertex additions" {
    const allocator = testing.allocator;

    var safe_graph = thread_safe_graph.ThreadSafeGraph.init(allocator);
    defer safe_graph.deinit();

    const ThreadContext = struct {
        graph: *thread_safe_graph.ThreadSafeGraph,
        id: usize,
    };

    const threadFunc = struct {
        fn run(ctx: ThreadContext) void {
            for (0..10) |i| {
                const content = std.fmt.allocPrint(
                    testing.allocator,
                    "Thread{d}-Vertex{d}",
                    .{ ctx.id, i },
                ) catch unreachable;
                defer testing.allocator.free(content);

                _ = ctx.graph.addVertex(content) catch unreachable;
            }
        }
    }.run;

    // Spawn multiple threads
    const num_threads = 4;
    var threads: [num_threads]std.Thread = undefined;

    for (0..num_threads) |i| {
        threads[i] = try std.Thread.spawn(
            .{},
            threadFunc,
            .{ThreadContext{ .graph = &safe_graph, .id = i }},
        );
    }

    for (threads) |thread| {
        thread.join();
    }

    // Each thread adds 10 vertices
    const expected_count = num_threads * 10;
    try testing.expectEqual(@as(usize, expected_count), safe_graph.getVertexCount());
}

test "ThreadSafeGraph: JSON serialization of vertices" {
    const allocator = testing.allocator;

    var safe_graph = thread_safe_graph.ThreadSafeGraph.init(allocator);
    defer safe_graph.deinit();

    _ = try safe_graph.addVertex("Concept A");
    _ = try safe_graph.addVertex("Concept B");

    var json_buf = std.ArrayList(u8).init(allocator);
    defer json_buf.deinit();

    try safe_graph.verticesToJson(json_buf.writer());

    const json = json_buf.items;
    try testing.expect(std.mem.indexOf(u8, json, "Concept A") != null);
    try testing.expect(std.mem.indexOf(u8, json, "Concept B") != null);
}

test "ThreadSafeGraph: JSON serialization of edges" {
    const allocator = testing.allocator;

    var safe_graph = thread_safe_graph.ThreadSafeGraph.init(allocator);
    defer safe_graph.deinit();

    const v1 = try safe_graph.addVertex("A");
    const v2 = try safe_graph.addVertex("B");

    try safe_graph.addOrUpdateEdge(v1, v2, .contradictory, 0.95);

    var json_buf = std.ArrayList(u8).init(allocator);
    defer json_buf.deinit();

    try safe_graph.edgesToJson(json_buf.writer());

    const json = json_buf.items;
    try testing.expect(std.mem.indexOf(u8, json, "contradictory") != null);
    try testing.expect(std.mem.indexOf(u8, json, "0.95") != null or std.mem.indexOf(u8, json, "0.9") != null);
}

test "ThreadSafeGraph: complete graph JSON serialization" {
    const allocator = testing.allocator;

    var safe_graph = thread_safe_graph.ThreadSafeGraph.init(allocator);
    defer safe_graph.deinit();

    const v1 = try safe_graph.addVertex("ML");
    const v2 = try safe_graph.addVertex("AI");

    try safe_graph.addOrUpdateEdge(v1, v2, .hierarchical, 0.85);

    var json_buf = std.ArrayList(u8).init(allocator);
    defer json_buf.deinit();

    try safe_graph.graphToJson(json_buf.writer());

    const json = json_buf.items;
    try testing.expect(std.mem.indexOf(u8, json, "vertices") != null);
    try testing.expect(std.mem.indexOf(u8, json, "edges") != null);
    try testing.expect(std.mem.indexOf(u8, json, "ML") != null);
    try testing.expect(std.mem.indexOf(u8, json, "AI") != null);
    try testing.expect(std.mem.indexOf(u8, json, "hierarchical") != null);
}

// TODO: Add test for concurrent edge updates with same vertices
// Multiple threads should be able to update the same edge, with highest certainty winning
// This is critical for multi-agent scenarios where agents may discover same relationships

// TODO: Add test for concurrent read-write operations
// Readers (snapshots, JSON serialization) should get consistent views while writers modify graph
// This ensures data consistency during concurrent access

// TODO: Add stress test with 50+ concurrent threads
// Verify stability and correctness under high load
// Measure performance degradation

// TODO: Add test for memory allocation failures
// Verify proper error propagation and no memory leaks on error paths
