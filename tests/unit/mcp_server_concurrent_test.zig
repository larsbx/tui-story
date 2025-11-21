const std = @import("std");
const testing = std.testing;
const mcp_server_concurrent = @import("mcp_server_concurrent");
const thread_safe_graph = @import("thread_safe_graph");
const llm = @import("llm");

test "ConcurrentMCPServer: initialization" {
    const allocator = testing.allocator;

    var safe_graph = thread_safe_graph.ThreadSafeGraph.init(allocator);
    defer safe_graph.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    var server = mcp_server_concurrent.ConcurrentMCPServer.init(
        allocator,
        &safe_graph,
        &llm_client,
        3000,
    );
    defer server.deinit();

    try testing.expectEqual(@as(u16, 3000), server.port);
}

test "ConcurrentMCPServer: initialize request" {
    const allocator = testing.allocator;

    var safe_graph = thread_safe_graph.ThreadSafeGraph.init(allocator);
    defer safe_graph.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    var server = mcp_server_concurrent.ConcurrentMCPServer.init(
        allocator,
        &safe_graph,
        &llm_client,
        3000,
    );
    defer server.deinit();

    const request =
        \\{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}
    ;

    const response = try server.handleRequest(request);
    defer allocator.free(response);

    try testing.expect(std.mem.indexOf(u8, response, "\"protocolVersion\":\"2025-06-18\"") != null);
    try testing.expect(std.mem.indexOf(u8, response, "semantic-graph-tui-concurrent") != null);
}

test "ConcurrentMCPServer: tools/list request" {
    const allocator = testing.allocator;

    var safe_graph = thread_safe_graph.ThreadSafeGraph.init(allocator);
    defer safe_graph.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    var server = mcp_server_concurrent.ConcurrentMCPServer.init(
        allocator,
        &safe_graph,
        &llm_client,
        3000,
    );
    defer server.deinit();

    const request =
        \\{"jsonrpc":"2.0","id":2,"method":"tools/list"}
    ;

    const response = try server.handleRequest(request);
    defer allocator.free(response);

    try testing.expect(std.mem.indexOf(u8, response, "add_idea") != null);
    try testing.expect(std.mem.indexOf(u8, response, "analyze_idea") != null);
    try testing.expect(std.mem.indexOf(u8, response, "get_graph") != null);
}

test "ConcurrentMCPServer: add_idea tool" {
    const allocator = testing.allocator;

    var safe_graph = thread_safe_graph.ThreadSafeGraph.init(allocator);
    defer safe_graph.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    var server = mcp_server_concurrent.ConcurrentMCPServer.init(
        allocator,
        &safe_graph,
        &llm_client,
        3000,
    );
    defer server.deinit();

    const request =
        \\{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"add_idea","arguments":{"content":"Test Idea"}}}
    ;

    const response = try server.handleRequest(request);
    defer allocator.free(response);

    try testing.expect(std.mem.indexOf(u8, response, "Idea added successfully") != null);
    try testing.expectEqual(@as(usize, 1), safe_graph.getVertexCount());
}

test "ConcurrentMCPServer: ping with graph stats" {
    const allocator = testing.allocator;

    var safe_graph = thread_safe_graph.ThreadSafeGraph.init(allocator);
    defer safe_graph.deinit();

    _ = try safe_graph.addVertex("V1");
    _ = try safe_graph.addVertex("V2");

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    var server = mcp_server_concurrent.ConcurrentMCPServer.init(
        allocator,
        &safe_graph,
        &llm_client,
        3000,
    );
    defer server.deinit();

    const request =
        \\{"jsonrpc":"2.0","id":4,"method":"ping"}
    ;

    const response = try server.handleRequest(request);
    defer allocator.free(response);

    try testing.expect(std.mem.indexOf(u8, response, "\"status\":\"ok\"") != null);
    try testing.expect(std.mem.indexOf(u8, response, "\"vertices\":2") != null);
}

test "ConcurrentMCPServer: list_ideas tool" {
    const allocator = testing.allocator;

    var safe_graph = thread_safe_graph.ThreadSafeGraph.init(allocator);
    defer safe_graph.deinit();

    _ = try safe_graph.addVertex("Idea One");
    _ = try safe_graph.addVertex("Idea Two");

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    var server = mcp_server_concurrent.ConcurrentMCPServer.init(
        allocator,
        &safe_graph,
        &llm_client,
        3000,
    );
    defer server.deinit();

    const request =
        \\{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"list_ideas","arguments":{}}}
    ;

    const response = try server.handleRequest(request);
    defer allocator.free(response);

    try testing.expect(std.mem.indexOf(u8, response, "Idea One") != null);
    try testing.expect(std.mem.indexOf(u8, response, "Idea Two") != null);
}

test "ConcurrentMCPServer: reset_graph tool" {
    const allocator = testing.allocator;

    var safe_graph = thread_safe_graph.ThreadSafeGraph.init(allocator);
    defer safe_graph.deinit();

    _ = try safe_graph.addVertex("Temp");
    try testing.expectEqual(@as(usize, 1), safe_graph.getVertexCount());

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    var server = mcp_server_concurrent.ConcurrentMCPServer.init(
        allocator,
        &safe_graph,
        &llm_client,
        3000,
    );
    defer server.deinit();

    const request =
        \\{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"reset_graph","arguments":{}}}
    ;

    const response = try server.handleRequest(request);
    defer allocator.free(response);

    try testing.expect(std.mem.indexOf(u8, response, "Graph cleared successfully") != null);
    try testing.expectEqual(@as(usize, 0), safe_graph.getVertexCount());
}

test "ConcurrentMCPServer: resources/list" {
    const allocator = testing.allocator;

    var safe_graph = thread_safe_graph.ThreadSafeGraph.init(allocator);
    defer safe_graph.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    var server = mcp_server_concurrent.ConcurrentMCPServer.init(
        allocator,
        &safe_graph,
        &llm_client,
        3000,
    );
    defer server.deinit();

    const request =
        \\{"jsonrpc":"2.0","id":7,"method":"resources/list"}
    ;

    const response = try server.handleRequest(request);
    defer allocator.free(response);

    try testing.expect(std.mem.indexOf(u8, response, "graph://state") != null);
    try testing.expect(std.mem.indexOf(u8, response, "graph://vertices") != null);
    try testing.expect(std.mem.indexOf(u8, response, "graph://edges") != null);
}

test "ConcurrentMCPServer: resources/read vertices" {
    const allocator = testing.allocator;

    var safe_graph = thread_safe_graph.ThreadSafeGraph.init(allocator);
    defer safe_graph.deinit();

    _ = try safe_graph.addVertex("Vertex A");

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    var server = mcp_server_concurrent.ConcurrentMCPServer.init(
        allocator,
        &safe_graph,
        &llm_client,
        3000,
    );
    defer server.deinit();

    const request =
        \\{"jsonrpc":"2.0","id":8,"method":"resources/read","params":{"uri":"graph://vertices"}}
    ;

    const response = try server.handleRequest(request);
    defer allocator.free(response);

    try testing.expect(std.mem.indexOf(u8, response, "Vertex A") != null);
}

test "ConcurrentMCPServer: concurrent requests simulation" {
    const allocator = testing.allocator;

    var safe_graph = thread_safe_graph.ThreadSafeGraph.init(allocator);
    defer safe_graph.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    var server = mcp_server_concurrent.ConcurrentMCPServer.init(
        allocator,
        &safe_graph,
        &llm_client,
        3000,
    );
    defer server.deinit();

    const ThreadContext = struct {
        srv: *mcp_server_concurrent.ConcurrentMCPServer,
        thread_id: usize,
        alloc: std.mem.Allocator,
    };

    const threadFunc = struct {
        fn run(ctx: ThreadContext) void {
            for (0..5) |i| {
                const content = std.fmt.allocPrint(
                    ctx.alloc,
                    "Thread{d}-Idea{d}",
                    .{ ctx.thread_id, i },
                ) catch unreachable;
                defer ctx.alloc.free(content);

                const request = std.fmt.allocPrint(
                    ctx.alloc,
                    \\{{"jsonrpc":"2.0","id":{d},"method":"tools/call","params":{{"name":"add_idea","arguments":{{"content":"{s}"}}}}}}
                ,
                    .{ ctx.thread_id * 100 + i, content },
                ) catch unreachable;
                defer ctx.alloc.free(request);

                const response = ctx.srv.handleRequest(request) catch unreachable;
                defer ctx.alloc.free(response);

                // Verify response is valid
                if (std.mem.indexOf(u8, response, "Idea added successfully") == null) {
                    @panic("Invalid response");
                }
            }
        }
    }.run;

    // Spawn multiple threads making concurrent requests
    const num_threads = 3;
    var threads: [num_threads]std.Thread = undefined;

    for (0..num_threads) |i| {
        threads[i] = try std.Thread.spawn(
            .{},
            threadFunc,
            .{ThreadContext{ .srv = &server, .thread_id = i, .alloc = allocator }},
        );
    }

    for (threads) |thread| {
        thread.join();
    }

    // Each thread adds 5 ideas
    const expected_count = num_threads * 5;
    try testing.expectEqual(@as(usize, expected_count), safe_graph.getVertexCount());
}

test "ConcurrentMCPServer: error handling for invalid requests" {
    const allocator = testing.allocator;

    var safe_graph = thread_safe_graph.ThreadSafeGraph.init(allocator);
    defer safe_graph.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    var server = mcp_server_concurrent.ConcurrentMCPServer.init(
        allocator,
        &safe_graph,
        &llm_client,
        3000,
    );
    defer server.deinit();

    // Invalid JSON-RPC version
    {
        const request =
            \\{"jsonrpc":"1.0","id":1,"method":"initialize"}
        ;
        const response = try server.handleRequest(request);
        defer allocator.free(response);

        try testing.expect(std.mem.indexOf(u8, response, "\"error\"") != null);
        try testing.expect(std.mem.indexOf(u8, response, "-32600") != null);
    }

    // Unknown method
    {
        const request =
            \\{"jsonrpc":"2.0","id":2,"method":"unknown_method"}
        ;
        const response = try server.handleRequest(request);
        defer allocator.free(response);

        try testing.expect(std.mem.indexOf(u8, response, "\"error\"") != null);
        try testing.expect(std.mem.indexOf(u8, response, "-32601") != null);
    }
}

// TODO: Add test for malformed JSON in request body
// Verify proper error response for invalid JSON

// TODO: Add test for large payload (close to 10MB limit)
// Verify memory limits are enforced

// TODO: Add test for concurrent analyze_idea operations
// This is the most complex operation - multiple threads analyzing different ideas
// Verify all relationships are added correctly without corruption

// TODO: Add HTTP integration test
// Actually start HTTP server, make real HTTP requests, verify responses

// TODO: Add multi-agent collaborative session integration test
// Simulate realistic scenario with 3+ agents working simultaneously
// Each agent adds ideas and analyzes, verify final graph is correct
