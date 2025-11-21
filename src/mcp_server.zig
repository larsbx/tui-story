const std = @import("std");
const graph = @import("graph.zig");
const llm = @import("llm.zig");
const analysis_service = @import("analysis_service.zig");
const validation = @import("validation.zig");

/// MCP (Model Context Protocol) Server
/// Implements JSON-RPC 2.0 over stdio for headless operation
pub const MCPServer = struct {
    allocator: std.mem.Allocator,
    graph_data: *graph.SemanticGraph,
    llm_client: *llm.LLMClient,
    analysis_service: *analysis_service.AnalysisService,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        graph_data: *graph.SemanticGraph,
        llm_client: *llm.LLMClient,
        analysis_svc: *analysis_service.AnalysisService,
    ) Self {
        return Self{
            .allocator = allocator,
            .graph_data = graph_data,
            .llm_client = llm_client,
            .analysis_service = analysis_svc,
        };
    }

    /// Run the MCP server (stdio transport)
    /// Reads JSON-RPC messages from stdin, writes responses to stdout
    /// Logs to stderr
    pub fn run(self: *Self) !void {
        const stdin = std.io.getStdIn().reader();
        const stdout = std.io.getStdOut().writer();
        const stderr = std.io.getStdErr().writer();

        try stderr.print("[MCP] Server starting...\n", .{});

        var buf_reader = std.io.bufferedReader(stdin);
        var reader = buf_reader.reader();

        while (true) {
            // Read line from stdin
            var line_buf = std.ArrayList(u8).init(self.allocator);
            defer line_buf.deinit();

            reader.streamUntilDelimiter(line_buf.writer(), '\n', null) catch |err| {
                if (err == error.EndOfStream) {
                    try stderr.print("[MCP] Client disconnected\n", .{});
                    break;
                }
                try stderr.print("[MCP] Error reading: {}\n", .{err});
                continue;
            };

            const line = line_buf.items;
            if (line.len == 0) continue;

            try stderr.print("[MCP] Received: {s}\n", .{line});

            // Parse and handle JSON-RPC request
            const response = self.handleRequest(line) catch |err| {
                try stderr.print("[MCP] Error handling request: {}\n", .{err});
                const error_response = try self.createErrorResponse(null, -32603, "Internal error");
                defer self.allocator.free(error_response);
                try stdout.print("{s}\n", .{error_response});
                continue;
            };
            defer self.allocator.free(response);

            try stdout.print("{s}\n", .{response});
            try stderr.print("[MCP] Sent: {s}\n", .{response});
        }
    }

    /// Handle a JSON-RPC request
    fn handleRequest(self: *Self, json_str: []const u8) ![]const u8 {
        var parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, json_str, .{});
        defer parsed.deinit();

        const root = parsed.value;

        // Validate JSON-RPC 2.0
        const jsonrpc = root.object.get("jsonrpc") orelse {
            return self.createErrorResponse(null, -32600, "Invalid Request: missing jsonrpc");
        };

        if (!std.mem.eql(u8, jsonrpc.string, "2.0")) {
            return self.createErrorResponse(null, -32600, "Invalid Request: jsonrpc must be '2.0'");
        }

        const method = root.object.get("method") orelse {
            return self.createErrorResponse(null, -32600, "Invalid Request: missing method");
        };

        const id = root.object.get("id");
        const params = root.object.get("params");

        // Route to method handler
        const method_str = method.string;

        if (std.mem.eql(u8, method_str, "initialize")) {
            return self.handleInitialize(id, params);
        } else if (std.mem.eql(u8, method_str, "tools/list")) {
            return self.handleToolsList(id);
        } else if (std.mem.eql(u8, method_str, "tools/call")) {
            return self.handleToolsCall(id, params);
        } else if (std.mem.eql(u8, method_str, "resources/list")) {
            return self.handleResourcesList(id);
        } else if (std.mem.eql(u8, method_str, "resources/read")) {
            return self.handleResourcesRead(id, params);
        } else if (std.mem.eql(u8, method_str, "ping")) {
            return self.handlePing(id);
        } else {
            return self.createErrorResponse(id, -32601, "Method not found");
        }
    }

    /// Handle initialize method
    fn handleInitialize(self: *Self, id: ?std.json.Value, _: ?std.json.Value) ![]const u8 {
        const response =
            \\{"jsonrpc":"2.0","id":
        ++ (if (id) |i| try self.jsonStringify(i) else "null") ++
            \\,"result":{"protocolVersion":"2025-06-18","serverInfo":{"name":"semantic-graph-tui","version":"0.1.0"},"capabilities":{"tools":{"listChanged":false},"resources":{"subscribe":false,"listChanged":false}}}}
        ;
        return self.allocator.dupe(u8, response);
    }

    /// Handle tools/list method
    fn handleToolsList(self: *Self, id: ?std.json.Value) ![]const u8 {
        const tools_json =
            \\[
            \\{"name":"add_idea","description":"Add a new concept/idea to the semantic graph","inputSchema":{"type":"object","properties":{"content":{"type":"string","description":"The concept or idea to add","minLength":1,"maxLength":1000}},"required":["content"]}},
            \\{"name":"analyze_idea","description":"Analyze a new idea against all existing ideas in the graph to discover relationships","inputSchema":{"type":"object","properties":{"content":{"type":"string","description":"The idea to analyze","minLength":1,"maxLength":1000}},"required":["content"]}},
            \\{"name":"get_graph","description":"Retrieve the complete semantic graph state including all vertices and edges","inputSchema":{"type":"object","properties":{}}},
            \\{"name":"list_ideas","description":"List all concepts/ideas in the graph","inputSchema":{"type":"object","properties":{}}},
            \\{"name":"reset_graph","description":"Clear all data from the semantic graph","inputSchema":{"type":"object","properties":{}}}
            \\]
        ;

        const response = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":{s},"result":{{"tools":{s}}}}}
        , .{ if (id) |i| try self.jsonStringify(i) else "null", tools_json });

        return response;
    }

    /// Handle tools/call method
    fn handleToolsCall(self: *Self, id: ?std.json.Value, params: ?std.json.Value) ![]const u8 {
        const p = params orelse {
            return self.createErrorResponse(id, -32602, "Invalid params: missing");
        };

        const name = p.object.get("name") orelse {
            return self.createErrorResponse(id, -32602, "Invalid params: missing 'name'");
        };

        const arguments = p.object.get("arguments") orelse {
            return self.createErrorResponse(id, -32602, "Invalid params: missing 'arguments'");
        };

        const tool_name = name.string;

        if (std.mem.eql(u8, tool_name, "add_idea")) {
            return self.toolAddIdea(id, arguments);
        } else if (std.mem.eql(u8, tool_name, "analyze_idea")) {
            return self.toolAnalyzeIdea(id, arguments);
        } else if (std.mem.eql(u8, tool_name, "get_graph")) {
            return self.toolGetGraph(id);
        } else if (std.mem.eql(u8, tool_name, "list_ideas")) {
            return self.toolListIdeas(id);
        } else if (std.mem.eql(u8, tool_name, "reset_graph")) {
            return self.toolResetGraph(id);
        } else {
            return self.createErrorResponse(id, -32602, "Unknown tool");
        }
    }

    /// Handle resources/list method
    fn handleResourcesList(self: *Self, id: ?std.json.Value) ![]const u8 {
        const resources_json =
            \\[
            \\{"uri":"graph://state","name":"Complete Graph State","description":"JSON representation of the entire semantic graph including vertices and edges","mimeType":"application/json"},
            \\{"uri":"graph://vertices","name":"Graph Vertices","description":"List of all concepts/ideas in the graph","mimeType":"application/json"},
            \\{"uri":"graph://edges","name":"Graph Edges","description":"List of all semantic relationships between ideas","mimeType":"application/json"}
            \\]
        ;

        const response = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":{s},"result":{{"resources":{s}}}}}
        , .{ if (id) |i| try self.jsonStringify(i) else "null", resources_json });

        return response;
    }

    /// Handle resources/read method
    fn handleResourcesRead(self: *Self, id: ?std.json.Value, params: ?std.json.Value) ![]const u8 {
        const p = params orelse {
            return self.createErrorResponse(id, -32602, "Invalid params: missing");
        };

        const uri = p.object.get("uri") orelse {
            return self.createErrorResponse(id, -32602, "Invalid params: missing 'uri'");
        };

        const uri_str = uri.string;

        if (std.mem.eql(u8, uri_str, "graph://state")) {
            return self.resourceGraphState(id);
        } else if (std.mem.eql(u8, uri_str, "graph://vertices")) {
            return self.resourceVertices(id);
        } else if (std.mem.eql(u8, uri_str, "graph://edges")) {
            return self.resourceEdges(id);
        } else {
            return self.createErrorResponse(id, -32602, "Unknown resource URI");
        }
    }

    /// Handle ping method
    fn handlePing(self: *Self, id: ?std.json.Value) ![]const u8 {
        const response = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":{s},"result":{{"status":"ok"}}}}
        , .{if (id) |i| try self.jsonStringify(i) else "null"});

        return response;
    }

    // Tool implementations

    fn toolAddIdea(self: *Self, id: ?std.json.Value, arguments: std.json.Value) ![]const u8 {
        const content = arguments.object.get("content") orelse {
            return self.createErrorResponse(id, -32602, "Missing 'content' argument");
        };

        const content_str = content.string;

        // Validate
        if (validation.validateIdea(content_str)) |err_msg| {
            return self.createErrorResponse(id, -32602, err_msg);
        }

        // Add to graph
        _ = try self.graph_data.addVertex(content_str);

        const vertex_count = self.graph_data.vertices.count();
        const result = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":{s},"result":{{"content":[{{"type":"text","text":"Idea added successfully. Total ideas: {d}"}}]}}}}
        , .{ if (id) |i| try self.jsonStringify(i) else "null", vertex_count });

        return result;
    }

    fn toolAnalyzeIdea(self: *Self, id: ?std.json.Value, arguments: std.json.Value) ![]const u8 {
        const content = arguments.object.get("content") orelse {
            return self.createErrorResponse(id, -32602, "Missing 'content' argument");
        };

        const content_str = content.string;

        // Validate
        if (validation.validateIdea(content_str)) |err_msg| {
            return self.createErrorResponse(id, -32602, err_msg);
        }

        // Analyze
        const vertex_id = try self.analysis_service.analyzeNewIdea(content_str);
        const edges_added = self.graph_data.edges.count();

        const result = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":{s},"result":{{"content":[{{"type":"text","text":"Idea analyzed and added. Vertex ID: {s}, Total edges: {d}"}}]}}}}
        , .{ if (id) |i| try self.jsonStringify(i) else "null", vertex_id, edges_added });

        return result;
    }

    fn toolGetGraph(self: *Self, id: ?std.json.Value) ![]const u8 {
        // Serialize graph to JSON
        var graph_json = std.ArrayList(u8).init(self.allocator);
        defer graph_json.deinit();

        try graph_json.appendSlice("{\"vertices\":[");

        var vertex_iter = self.graph_data.vertices.iterator();
        var first_vertex = true;
        while (vertex_iter.next()) |entry| {
            if (!first_vertex) try graph_json.appendSlice(",");
            first_vertex = false;

            const v = entry.value_ptr;
            try std.fmt.format(graph_json.writer(),
                \\{{"id":"{s}","content":"{s}","x":{d:.2},"y":{d:.2}}}
            , .{ v.id, v.content, v.x, v.y });
        }

        try graph_json.appendSlice("],\"edges\":[");

        var edge_iter = self.graph_data.edges.iterator();
        var first_edge = true;
        while (edge_iter.next()) |entry| {
            if (!first_edge) try graph_json.appendSlice(",");
            first_edge = false;

            const e = entry.value_ptr;
            const rel_type = @tagName(e.relationship_type);
            try std.fmt.format(graph_json.writer(),
                \\{{"from":"{s}","to":"{s}","type":"{s}","certainty":{d:.2}}}
            , .{ e.from, e.to, rel_type, e.certainty });
        }

        try graph_json.appendSlice("]}");

        const escaped_json = try self.escapeJson(graph_json.items);
        defer self.allocator.free(escaped_json);

        const result = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":{s},"result":{{"content":[{{"type":"text","text":"{s}"}}]}}}}
        , .{ if (id) |i| try self.jsonStringify(i) else "null", escaped_json });

        return result;
    }

    fn toolListIdeas(self: *Self, id: ?std.json.Value) ![]const u8 {
        var ideas_list = std.ArrayList(u8).init(self.allocator);
        defer ideas_list.deinit();

        var vertex_iter = self.graph_data.vertices.iterator();
        var count: usize = 0;
        while (vertex_iter.next()) |entry| {
            count += 1;
            const v = entry.value_ptr;
            try std.fmt.format(ideas_list.writer(), "{d}. {s}\\n", .{ count, v.content });
        }

        const escaped_text = try self.escapeJson(ideas_list.items);
        defer self.allocator.free(escaped_text);

        const result = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":{s},"result":{{"content":[{{"type":"text","text":"{s}"}}]}}}}
        , .{ if (id) |i| try self.jsonStringify(i) else "null", escaped_text });

        return result;
    }

    fn toolResetGraph(self: *Self, id: ?std.json.Value) ![]const u8 {
        self.graph_data.clear();

        const result = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":{s},"result":{{"content":[{{"type":"text","text":"Graph cleared successfully"}}]}}}}
        , .{if (id) |i| try self.jsonStringify(i) else "null"});

        return result;
    }

    // Resource implementations

    fn resourceGraphState(self: *Self, id: ?std.json.Value) ![]const u8 {
        return self.toolGetGraph(id);
    }

    fn resourceVertices(self: *Self, id: ?std.json.Value) ![]const u8 {
        var vertices_json = std.ArrayList(u8).init(self.allocator);
        defer vertices_json.deinit();

        try vertices_json.appendSlice("[");

        var vertex_iter = self.graph_data.vertices.iterator();
        var first = true;
        while (vertex_iter.next()) |entry| {
            if (!first) try vertices_json.appendSlice(",");
            first = false;

            const v = entry.value_ptr;
            try std.fmt.format(vertices_json.writer(),
                \\{{"id":"{s}","content":"{s}","x":{d:.2},"y":{d:.2}}}
            , .{ v.id, v.content, v.x, v.y });
        }

        try vertices_json.appendSlice("]");

        const escaped_json = try self.escapeJson(vertices_json.items);
        defer self.allocator.free(escaped_json);

        const result = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":{s},"result":{{"contents":[{{"uri":"graph://vertices","mimeType":"application/json","text":"{s}"}}]}}}}
        , .{ if (id) |i| try self.jsonStringify(i) else "null", escaped_json });

        return result;
    }

    fn resourceEdges(self: *Self, id: ?std.json.Value) ![]const u8 {
        var edges_json = std.ArrayList(u8).init(self.allocator);
        defer edges_json.deinit();

        try edges_json.appendSlice("[");

        var edge_iter = self.graph_data.edges.iterator();
        var first = true;
        while (edge_iter.next()) |entry| {
            if (!first) try edges_json.appendSlice(",");
            first = false;

            const e = entry.value_ptr;
            const rel_type = @tagName(e.relationship_type);
            try std.fmt.format(edges_json.writer(),
                \\{{"from":"{s}","to":"{s}","type":"{s}","certainty":{d:.2}}}
            , .{ e.from, e.to, rel_type, e.certainty });
        }

        try edges_json.appendSlice("]");

        const escaped_json = try self.escapeJson(edges_json.items);
        defer self.allocator.free(escaped_json);

        const result = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":{s},"result":{{"contents":[{{"uri":"graph://edges","mimeType":"application/json","text":"{s}"}}]}}}}
        , .{ if (id) |i| try self.jsonStringify(i) else "null", escaped_json });

        return result;
    }

    // Helper functions

    fn createErrorResponse(self: *Self, id: ?std.json.Value, code: i32, message: []const u8) ![]const u8 {
        const escaped_msg = try self.escapeJson(message);
        defer self.allocator.free(escaped_msg);

        const response = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":{s},"error":{{"code":{d},"message":"{s}"}}}}
        , .{ if (id) |i| try self.jsonStringify(i) else "null", code, escaped_msg });

        return response;
    }

    fn jsonStringify(self: *Self, value: std.json.Value) ![]const u8 {
        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();

        try std.json.stringify(value, .{}, buf.writer());
        return self.allocator.dupe(u8, buf.items);
    }

    fn escapeJson(self: *Self, str: []const u8) ![]const u8 {
        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();

        for (str) |c| {
            switch (c) {
                '"' => try buf.appendSlice("\\\""),
                '\\' => try buf.appendSlice("\\\\"),
                '\n' => try buf.appendSlice("\\n"),
                '\r' => try buf.appendSlice("\\r"),
                '\t' => try buf.appendSlice("\\t"),
                else => try buf.append(c),
            }
        }

        return self.allocator.dupe(u8, buf.items);
    }
};
