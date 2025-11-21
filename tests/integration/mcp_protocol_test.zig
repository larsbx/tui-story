const std = @import("std");
const testing = std.testing;
const mcp_server = @import("mcp_server");
const graph = @import("graph");
const llm = @import("llm");
const analysis_service = @import("analysis_service");

/// Integration test: Complete MCP protocol flow
/// Tests the full lifecycle: initialize -> tools/list -> add ideas -> get graph
test "MCP Protocol Flow: Complete workflow" {
    const allocator = testing.allocator;

    var graph_data = graph.SemanticGraph.init(allocator);
    defer graph_data.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    var analysis_svc = analysis_service.AnalysisService.init(allocator, &graph_data, &llm_client);

    var server = mcp_server.MCPServer.init(allocator, &graph_data, &llm_client, &analysis_svc);

    // Step 1: Initialize connection
    {
        const request =
            \\{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}
        ;
        const response = try server.handleRequest(request);
        defer allocator.free(response);

        try testing.expect(std.mem.indexOf(u8, response, "\"protocolVersion\":\"2025-06-18\"") != null);
        try testing.expect(std.mem.indexOf(u8, response, "\"id\":1") != null);
    }

    // Step 2: List available tools
    {
        const request =
            \\{"jsonrpc":"2.0","id":2,"method":"tools/list"}
        ;
        const response = try server.handleRequest(request);
        defer allocator.free(response);

        try testing.expect(std.mem.indexOf(u8, response, "add_idea") != null);
        try testing.expect(std.mem.indexOf(u8, response, "get_graph") != null);
    }

    // Step 3: Add first idea
    {
        const request =
            \\{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"add_idea","arguments":{"content":"Machine Learning"}}}
        ;
        const response = try server.handleRequest(request);
        defer allocator.free(response);

        try testing.expect(std.mem.indexOf(u8, response, "Idea added successfully") != null);
    }

    // Step 4: Add second idea
    {
        const request =
            \\{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"add_idea","arguments":{"content":"Neural Networks"}}}
        ;
        const response = try server.handleRequest(request);
        defer allocator.free(response);

        try testing.expect(std.mem.indexOf(u8, response, "Idea added successfully") != null);
    }

    // Step 5: List all ideas
    {
        const request =
            \\{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"list_ideas","arguments":{}}}
        ;
        const response = try server.handleRequest(request);
        defer allocator.free(response);

        try testing.expect(std.mem.indexOf(u8, response, "Machine Learning") != null);
        try testing.expect(std.mem.indexOf(u8, response, "Neural Networks") != null);
    }

    // Step 6: Get complete graph
    {
        const request =
            \\{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"get_graph","arguments":{}}}
        ;
        const response = try server.handleRequest(request);
        defer allocator.free(response);

        try testing.expect(std.mem.indexOf(u8, response, "vertices") != null);
        try testing.expect(std.mem.indexOf(u8, response, "edges") != null);
    }

    // Step 7: List resources
    {
        const request =
            \\{"jsonrpc":"2.0","id":7,"method":"resources/list"}
        ;
        const response = try server.handleRequest(request);
        defer allocator.free(response);

        try testing.expect(std.mem.indexOf(u8, response, "graph://state") != null);
        try testing.expect(std.mem.indexOf(u8, response, "graph://vertices") != null);
        try testing.expect(std.mem.indexOf(u8, response, "graph://edges") != null);
    }

    // Step 8: Read vertices resource
    {
        const request =
            \\{"jsonrpc":"2.0","id":8,"method":"resources/read","params":{"uri":"graph://vertices"}}
        ;
        const response = try server.handleRequest(request);
        defer allocator.free(response);

        try testing.expect(std.mem.indexOf(u8, response, "Machine Learning") != null);
        try testing.expect(std.mem.indexOf(u8, response, "Neural Networks") != null);
    }

    // Step 9: Reset graph
    {
        const request =
            \\{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"reset_graph","arguments":{}}}
        ;
        const response = try server.handleRequest(request);
        defer allocator.free(response);

        try testing.expect(std.mem.indexOf(u8, response, "Graph cleared successfully") != null);
        try testing.expectEqual(@as(usize, 0), graph_data.vertices.count());
    }
}

/// Integration test: Multiple agents workflow
/// Simulates multiple MCP clients working with the same graph
test "MCP Protocol Flow: Multi-agent collaboration" {
    const allocator = testing.allocator;

    var graph_data = graph.SemanticGraph.init(allocator);
    defer graph_data.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    var analysis_svc = analysis_service.AnalysisService.init(allocator, &graph_data, &llm_client);

    // Agent 1 and Agent 2 share the same graph
    var agent1 = mcp_server.MCPServer.init(allocator, &graph_data, &llm_client, &analysis_svc);
    var agent2 = mcp_server.MCPServer.init(allocator, &graph_data, &llm_client, &analysis_svc);

    // Agent 1: Add concepts
    {
        const request =
            \\{"jsonrpc":"2.0","id":101,"method":"tools/call","params":{"name":"add_idea","arguments":{"content":"Distributed Systems"}}}
        ;
        const response = try agent1.handleRequest(request);
        defer allocator.free(response);

        try testing.expect(std.mem.indexOf(u8, response, "Idea added successfully") != null);
    }

    // Agent 2: Add related concepts (sees Agent 1's data)
    {
        const request =
            \\{"jsonrpc":"2.0","id":201,"method":"tools/call","params":{"name":"add_idea","arguments":{"content":"Consensus Algorithms"}}}
        ;
        const response = try agent2.handleRequest(request);
        defer allocator.free(response);

        try testing.expect(std.mem.indexOf(u8, response, "Total ideas: 2") != null);
    }

    // Agent 1: List all ideas (sees both agents' contributions)
    {
        const request =
            \\{"jsonrpc":"2.0","id":102,"method":"tools/call","params":{"name":"list_ideas","arguments":{}}}
        ;
        const response = try agent1.handleRequest(request);
        defer allocator.free(response);

        try testing.expect(std.mem.indexOf(u8, response, "Distributed Systems") != null);
        try testing.expect(std.mem.indexOf(u8, response, "Consensus Algorithms") != null);
    }

    // Agent 2: Get graph state
    {
        const request =
            \\{"jsonrpc":"2.0","id":202,"method":"tools/call","params":{"name":"get_graph","arguments":{}}}
        ;
        const response = try agent2.handleRequest(request);
        defer allocator.free(response);

        try testing.expect(std.mem.indexOf(u8, response, "Distributed Systems") != null);
        try testing.expect(std.mem.indexOf(u8, response, "Consensus Algorithms") != null);
    }

    // Verify shared state
    try testing.expectEqual(@as(usize, 2), graph_data.vertices.count());
}

/// Integration test: Error handling flow
test "MCP Protocol Flow: Error handling" {
    const allocator = testing.allocator;

    var graph_data = graph.SemanticGraph.init(allocator);
    defer graph_data.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    var analysis_svc = analysis_service.AnalysisService.init(allocator, &graph_data, &llm_client);

    var server = mcp_server.MCPServer.init(allocator, &graph_data, &llm_client, &analysis_svc);

    // Test 1: Invalid JSON-RPC version
    {
        const request =
            \\{"jsonrpc":"1.0","id":1,"method":"initialize"}
        ;
        const response = try server.handleRequest(request);
        defer allocator.free(response);

        try testing.expect(std.mem.indexOf(u8, response, "\"error\"") != null);
        try testing.expect(std.mem.indexOf(u8, response, "-32600") != null);
    }

    // Test 2: Unknown method
    {
        const request =
            \\{"jsonrpc":"2.0","id":2,"method":"nonexistent"}
        ;
        const response = try server.handleRequest(request);
        defer allocator.free(response);

        try testing.expect(std.mem.indexOf(u8, response, "\"error\"") != null);
        try testing.expect(std.mem.indexOf(u8, response, "-32601") != null);
    }

    // Test 3: Invalid params
    {
        const request =
            \\{"jsonrpc":"2.0","id":3,"method":"tools/call"}
        ;
        const response = try server.handleRequest(request);
        defer allocator.free(response);

        try testing.expect(std.mem.indexOf(u8, response, "\"error\"") != null);
        try testing.expect(std.mem.indexOf(u8, response, "-32602") != null);
    }

    // Test 4: Validation error (empty content)
    {
        const request =
            \\{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"add_idea","arguments":{"content":""}}}
        ;
        const response = try server.handleRequest(request);
        defer allocator.free(response);

        try testing.expect(std.mem.indexOf(u8, response, "\"error\"") != null);
    }

    // Test 5: Unknown tool
    {
        const request =
            \\{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"unknown_tool","arguments":{}}}
        ;
        const response = try server.handleRequest(request);
        defer allocator.free(response);

        try testing.expect(std.mem.indexOf(u8, response, "\"error\"") != null);
    }

    // Test 6: Unknown resource
    {
        const request =
            \\{"jsonrpc":"2.0","id":6,"method":"resources/read","params":{"uri":"unknown://resource"}}
        ;
        const response = try server.handleRequest(request);
        defer allocator.free(response);

        try testing.expect(std.mem.indexOf(u8, response, "\"error\"") != null);
    }

    // Verify graph is still empty (no data was added due to errors)
    try testing.expectEqual(@as(usize, 0), graph_data.vertices.count());
}

/// Integration test: Resource subscriptions workflow
test "MCP Protocol Flow: Resources workflow" {
    const allocator = testing.allocator;

    var graph_data = graph.SemanticGraph.init(allocator);
    defer graph_data.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    var analysis_svc = analysis_service.AnalysisService.init(allocator, &graph_data, &llm_client);

    var server = mcp_server.MCPServer.init(allocator, &graph_data, &llm_client, &analysis_svc);

    // Add some data
    const v1 = try graph_data.addVertex("Quantum Computing");
    const v2 = try graph_data.addVertex("Superposition");
    try graph_data.addOrUpdateEdge(v1, v2, .HIERARCHICAL, 0.85);

    // Read graph state resource
    {
        const request =
            \\{"jsonrpc":"2.0","id":1,"method":"resources/read","params":{"uri":"graph://state"}}
        ;
        const response = try server.handleRequest(request);
        defer allocator.free(response);

        try testing.expect(std.mem.indexOf(u8, response, "Quantum Computing") != null);
        try testing.expect(std.mem.indexOf(u8, response, "Superposition") != null);
        try testing.expect(std.mem.indexOf(u8, response, "HIERARCHICAL") != null);
    }

    // Read vertices resource
    {
        const request =
            \\{"jsonrpc":"2.0","id":2,"method":"resources/read","params":{"uri":"graph://vertices"}}
        ;
        const response = try server.handleRequest(request);
        defer allocator.free(response);

        try testing.expect(std.mem.indexOf(u8, response, "Quantum Computing") != null);
        try testing.expect(std.mem.indexOf(u8, response, "Superposition") != null);
    }

    // Read edges resource
    {
        const request =
            \\{"jsonrpc":"2.0","id":3,"method":"resources/read","params":{"uri":"graph://edges"}}
        ;
        const response = try server.handleRequest(request);
        defer allocator.free(response);

        try testing.expect(std.mem.indexOf(u8, response, "HIERARCHICAL") != null);
        try testing.expect(std.mem.indexOf(u8, response, "0.85") != null or std.mem.indexOf(u8, response, "0.8") != null);
    }
}
