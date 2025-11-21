const std = @import("std");
const testing = std.testing;
const mcp_server = @import("mcp_server");
const graph = @import("graph");
const llm = @import("llm");
const analysis_service = @import("analysis_service");

test "MCPServer: initialize request" {
    const allocator = testing.allocator;

    var graph_data = graph.SemanticGraph.init(allocator);
    defer graph_data.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    var analysis_svc = analysis_service.AnalysisService.init(allocator, &graph_data, &llm_client);

    var server = mcp_server.MCPServer.init(allocator, &graph_data, &llm_client, &analysis_svc);

    const request =
        \\{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}
    ;

    const response = try server.handleRequest(request);
    defer allocator.free(response);

    try testing.expect(std.mem.indexOf(u8, response, "\"protocolVersion\":\"2025-06-18\"") != null);
    try testing.expect(std.mem.indexOf(u8, response, "\"serverInfo\"") != null);
    try testing.expect(std.mem.indexOf(u8, response, "\"semantic-graph-tui\"") != null);
}

test "MCPServer: tools/list request" {
    const allocator = testing.allocator;

    var graph_data = graph.SemanticGraph.init(allocator);
    defer graph_data.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    var analysis_svc = analysis_service.AnalysisService.init(allocator, &graph_data, &llm_client);

    var server = mcp_server.MCPServer.init(allocator, &graph_data, &llm_client, &analysis_svc);

    const request =
        \\{"jsonrpc":"2.0","id":2,"method":"tools/list"}
    ;

    const response = try server.handleRequest(request);
    defer allocator.free(response);

    try testing.expect(std.mem.indexOf(u8, response, "\"tools\"") != null);
    try testing.expect(std.mem.indexOf(u8, response, "add_idea") != null);
    try testing.expect(std.mem.indexOf(u8, response, "analyze_idea") != null);
    try testing.expect(std.mem.indexOf(u8, response, "get_graph") != null);
    try testing.expect(std.mem.indexOf(u8, response, "list_ideas") != null);
    try testing.expect(std.mem.indexOf(u8, response, "reset_graph") != null);
}

test "MCPServer: resources/list request" {
    const allocator = testing.allocator;

    var graph_data = graph.SemanticGraph.init(allocator);
    defer graph_data.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    var analysis_svc = analysis_service.AnalysisService.init(allocator, &graph_data, &llm_client);

    var server = mcp_server.MCPServer.init(allocator, &graph_data, &llm_client, &analysis_svc);

    const request =
        \\{"jsonrpc":"2.0","id":3,"method":"resources/list"}
    ;

    const response = try server.handleRequest(request);
    defer allocator.free(response);

    try testing.expect(std.mem.indexOf(u8, response, "\"resources\"") != null);
    try testing.expect(std.mem.indexOf(u8, response, "graph://state") != null);
    try testing.expect(std.mem.indexOf(u8, response, "graph://vertices") != null);
    try testing.expect(std.mem.indexOf(u8, response, "graph://edges") != null);
}

test "MCPServer: add_idea tool" {
    const allocator = testing.allocator;

    var graph_data = graph.SemanticGraph.init(allocator);
    defer graph_data.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    var analysis_svc = analysis_service.AnalysisService.init(allocator, &graph_data, &llm_client);

    var server = mcp_server.MCPServer.init(allocator, &graph_data, &llm_client, &analysis_svc);

    const request =
        \\{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"add_idea","arguments":{"content":"Test concept"}}}
    ;

    const response = try server.handleRequest(request);
    defer allocator.free(response);

    try testing.expect(std.mem.indexOf(u8, response, "Idea added successfully") != null);
    try testing.expectEqual(@as(usize, 1), graph_data.vertices.count());
}

test "MCPServer: list_ideas tool" {
    const allocator = testing.allocator;

    var graph_data = graph.SemanticGraph.init(allocator);
    defer graph_data.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    var analysis_svc = analysis_service.AnalysisService.init(allocator, &graph_data, &llm_client);

    var server = mcp_server.MCPServer.init(allocator, &graph_data, &llm_client, &analysis_svc);

    // Add some ideas first
    _ = try graph_data.addVertex("First idea");
    _ = try graph_data.addVertex("Second idea");

    const request =
        \\{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"list_ideas","arguments":{}}}
    ;

    const response = try server.handleRequest(request);
    defer allocator.free(response);

    try testing.expect(std.mem.indexOf(u8, response, "First idea") != null);
    try testing.expect(std.mem.indexOf(u8, response, "Second idea") != null);
}

test "MCPServer: get_graph tool" {
    const allocator = testing.allocator;

    var graph_data = graph.SemanticGraph.init(allocator);
    defer graph_data.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    var analysis_svc = analysis_service.AnalysisService.init(allocator, &graph_data, &llm_client);

    var server = mcp_server.MCPServer.init(allocator, &graph_data, &llm_client, &analysis_svc);

    // Add vertex and edge
    const v1 = try graph_data.addVertex("Concept A");
    const v2 = try graph_data.addVertex("Concept B");
    try graph_data.addOrUpdateEdge(v1, v2, .IMPLICATIVE, 0.8);

    const request =
        \\{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"get_graph","arguments":{}}}
    ;

    const response = try server.handleRequest(request);
    defer allocator.free(response);

    try testing.expect(std.mem.indexOf(u8, response, "vertices") != null);
    try testing.expect(std.mem.indexOf(u8, response, "edges") != null);
    try testing.expect(std.mem.indexOf(u8, response, "Concept A") != null);
    try testing.expect(std.mem.indexOf(u8, response, "Concept B") != null);
}

test "MCPServer: reset_graph tool" {
    const allocator = testing.allocator;

    var graph_data = graph.SemanticGraph.init(allocator);
    defer graph_data.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    var analysis_svc = analysis_service.AnalysisService.init(allocator, &graph_data, &llm_client);

    var server = mcp_server.MCPServer.init(allocator, &graph_data, &llm_client, &analysis_svc);

    // Add some data
    _ = try graph_data.addVertex("Test");
    try testing.expectEqual(@as(usize, 1), graph_data.vertices.count());

    const request =
        \\{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"reset_graph","arguments":{}}}
    ;

    const response = try server.handleRequest(request);
    defer allocator.free(response);

    try testing.expect(std.mem.indexOf(u8, response, "Graph cleared successfully") != null);
    try testing.expectEqual(@as(usize, 0), graph_data.vertices.count());
}

test "MCPServer: resources/read graph://vertices" {
    const allocator = testing.allocator;

    var graph_data = graph.SemanticGraph.init(allocator);
    defer graph_data.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    var analysis_svc = analysis_service.AnalysisService.init(allocator, &graph_data, &llm_client);

    var server = mcp_server.MCPServer.init(allocator, &graph_data, &llm_client, &analysis_svc);

    _ = try graph_data.addVertex("Vertex 1");
    _ = try graph_data.addVertex("Vertex 2");

    const request =
        \\{"jsonrpc":"2.0","id":8,"method":"resources/read","params":{"uri":"graph://vertices"}}
    ;

    const response = try server.handleRequest(request);
    defer allocator.free(response);

    try testing.expect(std.mem.indexOf(u8, response, "\"contents\"") != null);
    try testing.expect(std.mem.indexOf(u8, response, "Vertex 1") != null);
    try testing.expect(std.mem.indexOf(u8, response, "Vertex 2") != null);
}

test "MCPServer: resources/read graph://edges" {
    const allocator = testing.allocator;

    var graph_data = graph.SemanticGraph.init(allocator);
    defer graph_data.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    var analysis_svc = analysis_service.AnalysisService.init(allocator, &graph_data, &llm_client);

    var server = mcp_server.MCPServer.init(allocator, &graph_data, &llm_client, &analysis_svc);

    const v1 = try graph_data.addVertex("A");
    const v2 = try graph_data.addVertex("B");
    try graph_data.addOrUpdateEdge(v1, v2, .HIERARCHICAL, 0.9);

    const request =
        \\{"jsonrpc":"2.0","id":9,"method":"resources/read","params":{"uri":"graph://edges"}}
    ;

    const response = try server.handleRequest(request);
    defer allocator.free(response);

    try testing.expect(std.mem.indexOf(u8, response, "\"contents\"") != null);
    try testing.expect(std.mem.indexOf(u8, response, "HIERARCHICAL") != null);
}

test "MCPServer: invalid JSON-RPC version" {
    const allocator = testing.allocator;

    var graph_data = graph.SemanticGraph.init(allocator);
    defer graph_data.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    var analysis_svc = analysis_service.AnalysisService.init(allocator, &graph_data, &llm_client);

    var server = mcp_server.MCPServer.init(allocator, &graph_data, &llm_client, &analysis_svc);

    const request =
        \\{"jsonrpc":"1.0","id":1,"method":"initialize"}
    ;

    const response = try server.handleRequest(request);
    defer allocator.free(response);

    try testing.expect(std.mem.indexOf(u8, response, "\"error\"") != null);
    try testing.expect(std.mem.indexOf(u8, response, "-32600") != null);
}

test "MCPServer: missing method" {
    const allocator = testing.allocator;

    var graph_data = graph.SemanticGraph.init(allocator);
    defer graph_data.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    var analysis_svc = analysis_service.AnalysisService.init(allocator, &graph_data, &llm_client);

    var server = mcp_server.MCPServer.init(allocator, &graph_data, &llm_client, &analysis_svc);

    const request =
        \\{"jsonrpc":"2.0","id":1}
    ;

    const response = try server.handleRequest(request);
    defer allocator.free(response);

    try testing.expect(std.mem.indexOf(u8, response, "\"error\"") != null);
    try testing.expect(std.mem.indexOf(u8, response, "missing method") != null);
}

test "MCPServer: unknown method" {
    const allocator = testing.allocator;

    var graph_data = graph.SemanticGraph.init(allocator);
    defer graph_data.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    var analysis_svc = analysis_service.AnalysisService.init(allocator, &graph_data, &llm_client);

    var server = mcp_server.MCPServer.init(allocator, &graph_data, &llm_client, &analysis_svc);

    const request =
        \\{"jsonrpc":"2.0","id":1,"method":"unknown_method"}
    ;

    const response = try server.handleRequest(request);
    defer allocator.free(response);

    try testing.expect(std.mem.indexOf(u8, response, "\"error\"") != null);
    try testing.expect(std.mem.indexOf(u8, response, "-32601") != null);
    try testing.expect(std.mem.indexOf(u8, response, "Method not found") != null);
}

test "MCPServer: ping method" {
    const allocator = testing.allocator;

    var graph_data = graph.SemanticGraph.init(allocator);
    defer graph_data.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    var analysis_svc = analysis_service.AnalysisService.init(allocator, &graph_data, &llm_client);

    var server = mcp_server.MCPServer.init(allocator, &graph_data, &llm_client, &analysis_svc);

    const request =
        \\{"jsonrpc":"2.0","id":10,"method":"ping"}
    ;

    const response = try server.handleRequest(request);
    defer allocator.free(response);

    try testing.expect(std.mem.indexOf(u8, response, "\"status\":\"ok\"") != null);
}

test "MCPServer: validation error for empty content" {
    const allocator = testing.allocator;

    var graph_data = graph.SemanticGraph.init(allocator);
    defer graph_data.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    var analysis_svc = analysis_service.AnalysisService.init(allocator, &graph_data, &llm_client);

    var server = mcp_server.MCPServer.init(allocator, &graph_data, &llm_client, &analysis_svc);

    const request =
        \\{"jsonrpc":"2.0","id":11,"method":"tools/call","params":{"name":"add_idea","arguments":{"content":""}}}
    ;

    const response = try server.handleRequest(request);
    defer allocator.free(response);

    try testing.expect(std.mem.indexOf(u8, response, "\"error\"") != null);
}
