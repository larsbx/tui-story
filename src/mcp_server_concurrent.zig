const std = @import("std");
const thread_safe_graph = @import("thread_safe_graph.zig");
const llm = @import("llm.zig");
const analysis_service = @import("analysis_service.zig");
const validation = @import("validation.zig");
const graph = @import("graph.zig");

/// Concurrent MCP Server supporting multiple simultaneous clients
/// Uses ThreadSafeGraph for synchronized access
pub const ConcurrentMCPServer = struct {
    allocator: std.mem.Allocator,
    graph_data: *thread_safe_graph.ThreadSafeGraph,
    llm_client: *llm.LLMClient,
    http_server: ?std.http.Server,
    port: u16,
    should_stop: std.atomic.Value(bool),

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        safe_graph: *thread_safe_graph.ThreadSafeGraph,
        llm_client_ptr: *llm.LLMClient,
        port: u16,
    ) Self {
        return Self{
            .allocator = allocator,
            .graph_data = safe_graph,
            .llm_client = llm_client_ptr,
            .http_server = null,
            .port = port,
            .should_stop = std.atomic.Value(bool).init(false),
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.http_server) |*server| {
            server.deinit();
        }
    }

    /// Run HTTP server for concurrent connections
    pub fn runHTTP(self: *Self) !void {
        const stderr = std.io.getStdErr().writer();
        try stderr.print("[MCP-HTTP] Starting server on port {}...\n", .{self.port});

        const address = std.net.Address.parseIp("127.0.0.1", self.port) catch unreachable;

        var server = std.http.Server.init(self.allocator, .{});
        defer server.deinit();
        self.http_server = server;

        try server.listen(address);
        try stderr.print("[MCP-HTTP] Server listening on http://127.0.0.1:{}\n", .{self.port});

        while (!self.should_stop.load(.acquire)) {
            // Accept connection
            var response = try server.accept(.{
                .allocator = self.allocator,
            });
            defer response.deinit();

            // Handle request in a new thread for true concurrency
            const thread = try std.Thread.spawn(.{}, handleConnection, .{ self, &response });
            thread.detach();
        }
    }

    fn handleConnection(self: *Self, response: *std.http.Server.Response) !void {
        const stderr = std.io.getStdErr().writer();

        // Read request body
        var body_buf = std.ArrayList(u8).init(self.allocator);
        defer body_buf.deinit();

        const max_size = 10 * 1024 * 1024; // 10MB max
        try response.reader().readAllArrayList(&body_buf, max_size);

        const request_body = body_buf.items;

        stderr.print("[MCP-HTTP] Request: {s}\n", .{request_body}) catch {};

        // Handle JSON-RPC request
        const json_response = self.handleRequest(request_body) catch |err| {
            stderr.print("[MCP-HTTP] Error: {}\n", .{err}) catch {};
            const error_resp = self.createErrorResponse(null, -32603, "Internal error") catch {
                return error.InternalError;
            };
            defer self.allocator.free(error_resp);

            try response.headers.append("content-type", "application/json");
            try response.headers.append("access-control-allow-origin", "*");
            try response.do();
            try response.writeAll(error_resp);
            try response.finish();
            return;
        };
        defer self.allocator.free(json_response);

        // Send response
        try response.headers.append("content-type", "application/json");
        try response.headers.append("access-control-allow-origin", "*");
        try response.do();
        try response.writeAll(json_response);
        try response.finish();

        stderr.print("[MCP-HTTP] Response sent\n", .{}) catch {};
    }

    pub fn stop(self: *Self) void {
        self.should_stop.store(true, .release);
    }

    /// Handle a JSON-RPC request (thread-safe)
    pub fn handleRequest(self: *Self, json_str: []const u8) ![]const u8 {
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

    fn handleInitialize(self: *Self, id: ?std.json.Value, _: ?std.json.Value) ![]const u8 {
        const response =
            \\{"jsonrpc":"2.0","id":
        ++ (if (id) |i| try self.jsonStringify(i) else "null") ++
            \\,"result":{"protocolVersion":"2025-06-18","serverInfo":{"name":"semantic-graph-tui-concurrent","version":"0.1.0"},"capabilities":{"tools":{"listChanged":false},"resources":{"subscribe":false,"listChanged":false}}}}
        ;
        return self.allocator.dupe(u8, response);
    }

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

    fn handlePing(self: *Self, id: ?std.json.Value) ![]const u8 {
        const response = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":{s},"result":{{"status":"ok","vertices":{d},"edges":{d}}}}}
        , .{
            if (id) |i| try self.jsonStringify(i) else "null",
            self.graph_data.getVertexCount(),
            self.graph_data.getEdgeCount(),
        });

        return response;
    }

    // Tool implementations (thread-safe)

    fn toolAddIdea(self: *Self, id: ?std.json.Value, arguments: std.json.Value) ![]const u8 {
        const content = arguments.object.get("content") orelse {
            return self.createErrorResponse(id, -32602, "Missing 'content' argument");
        };

        const content_str = content.string;

        // Validate
        if (validation.validateIdea(content_str)) |err_msg| {
            return self.createErrorResponse(id, -32602, err_msg);
        }

        // Add to graph (thread-safe)
        _ = try self.graph_data.addVertex(content_str);

        const vertex_count = self.graph_data.getVertexCount();
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

        // For analysis, we need to create a temporary AnalysisService
        // This is thread-safe because each request gets its own service instance
        const vertex_id = blk: {
            // Lock the graph for the duration of analysis
            self.graph_data.mutex.lock();
            defer self.graph_data.mutex.unlock();

            var analysis_svc = analysis_service.AnalysisService.init(
                self.allocator,
                &self.graph_data.graph_data,
                self.llm_client,
            );

            break :blk try analysis_svc.analyzeNewIdea(content_str);
        };

        const edges_added = self.graph_data.getEdgeCount();

        const result = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":{s},"result":{{"content":[{{"type":"text","text":"Idea analyzed and added. Vertex ID: {s}, Total edges: {d}"}}]}}}}
        , .{ if (id) |i| try self.jsonStringify(i) else "null", vertex_id, edges_added });

        return result;
    }

    fn toolGetGraph(self: *Self, id: ?std.json.Value) ![]const u8 {
        var graph_json = std.ArrayList(u8).init(self.allocator);
        defer graph_json.deinit();

        try self.graph_data.graphToJson(graph_json.writer());

        const escaped_json = try self.escapeJson(graph_json.items);
        defer self.allocator.free(escaped_json);

        const result = try std.fmt.allocPrint(self.allocator,
            \\{{"jsonrpc":"2.0","id":{s},"result":{{"content":[{{"type":"text","text":"{s}"}}]}}}}
        , .{ if (id) |i| try self.jsonStringify(i) else "null", escaped_json });

        return result;
    }

    fn toolListIdeas(self: *Self, id: ?std.json.Value) ![]const u8 {
        const vertices = try self.graph_data.getVerticesSnapshot();
        defer self.allocator.free(vertices);

        var ideas_list = std.ArrayList(u8).init(self.allocator);
        defer ideas_list.deinit();

        for (vertices, 0..) |v, i| {
            try std.fmt.format(ideas_list.writer(), "{d}. {s}\\n", .{ i + 1, v.content });
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

    // Resource implementations (thread-safe)

    fn resourceGraphState(self: *Self, id: ?std.json.Value) ![]const u8 {
        return self.toolGetGraph(id);
    }

    fn resourceVertices(self: *Self, id: ?std.json.Value) ![]const u8 {
        var vertices_json = std.ArrayList(u8).init(self.allocator);
        defer vertices_json.deinit();

        try self.graph_data.verticesToJson(vertices_json.writer());

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

        try self.graph_data.edgesToJson(edges_json.writer());

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
