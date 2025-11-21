const std = @import("std");
const graph = @import("graph.zig");

/// Thread-safe wrapper around SemanticGraph for concurrent access
/// Uses a mutex to synchronize access from multiple threads/clients
pub const ThreadSafeGraph = struct {
    allocator: std.mem.Allocator,
    graph_data: graph.SemanticGraph,
    mutex: std.Thread.Mutex,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .graph_data = graph.SemanticGraph.init(allocator),
            .mutex = std.Thread.Mutex{},
        };
    }

    pub fn deinit(self: *Self) void {
        self.graph_data.deinit();
    }

    /// Add a vertex to the graph (thread-safe)
    pub fn addVertex(self: *Self, content: []const u8) ![]const u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        return try self.graph_data.addVertex(content);
    }

    /// Add or update an edge (thread-safe)
    pub fn addOrUpdateEdge(
        self: *Self,
        from: []const u8,
        to: []const u8,
        relationship_type: graph.RelationType,
        certainty: f32,
    ) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        return try self.graph_data.addOrUpdateEdge(from, to, relationship_type, certainty);
    }

    /// Clear all data (thread-safe)
    pub fn clear(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.graph_data.clear();
    }

    /// Get vertex count (thread-safe)
    pub fn getVertexCount(self: *Self) usize {
        self.mutex.lock();
        defer self.mutex.unlock();

        return self.graph_data.vertices.count();
    }

    /// Get edge count (thread-safe)
    pub fn getEdgeCount(self: *Self) usize {
        self.mutex.lock();
        defer self.mutex.unlock();

        return self.graph_data.edges.count();
    }

    /// Execute a function with exclusive access to the graph
    /// This is useful for operations that need to read/write multiple times atomically
    pub fn withLock(self: *Self, comptime func: anytype, args: anytype) !@TypeOf(func) {
        self.mutex.lock();
        defer self.mutex.unlock();

        return @call(.auto, func, .{&self.graph_data} ++ args);
    }

    /// Execute a read-only function with shared access to the graph
    /// For now, still uses exclusive lock (can be optimized with RwLock in the future)
    pub fn withReadLock(self: *Self, comptime func: anytype, args: anytype) !@TypeOf(func) {
        self.mutex.lock();
        defer self.mutex.unlock();

        return @call(.auto, func, .{&self.graph_data} ++ args);
    }

    /// Get a snapshot of all vertices (thread-safe)
    /// Returns an array that must be freed by the caller
    pub fn getVerticesSnapshot(self: *Self) ![]graph.Vertex {
        self.mutex.lock();
        defer self.mutex.unlock();

        var vertices = std.ArrayList(graph.Vertex).init(self.allocator);
        errdefer vertices.deinit();

        var iter = self.graph_data.vertices.iterator();
        while (iter.next()) |entry| {
            try vertices.append(entry.value_ptr.*);
        }

        return vertices.toOwnedSlice();
    }

    /// Get a snapshot of all edges (thread-safe)
    /// Returns an array that must be freed by the caller
    pub fn getEdgesSnapshot(self: *Self) ![]graph.Edge {
        self.mutex.lock();
        defer self.mutex.unlock();

        var edges = std.ArrayList(graph.Edge).init(self.allocator);
        errdefer edges.deinit();

        var iter = self.graph_data.edges.iterator();
        while (iter.next()) |entry| {
            try edges.append(entry.value_ptr.*);
        }

        return edges.toOwnedSlice();
    }

    /// Get a vertex by ID (thread-safe)
    pub fn getVertex(self: *Self, id: []const u8) ?graph.Vertex {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.graph_data.vertices.get(id)) |vertex| {
            return vertex;
        }
        return null;
    }

    /// Check if a vertex exists (thread-safe)
    pub fn hasVertex(self: *Self, id: []const u8) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        return self.graph_data.vertices.contains(id);
    }

    /// Serialize vertices to JSON (thread-safe)
    pub fn verticesToJson(self: *Self, writer: anytype) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        try writer.writeAll("[");

        var vertex_iter = self.graph_data.vertices.iterator();
        var first = true;
        while (vertex_iter.next()) |entry| {
            if (!first) try writer.writeAll(",");
            first = false;

            const v = entry.value_ptr;
            try std.fmt.format(writer,
                \\{{"id":"{s}","content":"{s}","x":{d:.2},"y":{d:.2}}}
            , .{ v.id, v.content, v.x, v.y });
        }

        try writer.writeAll("]");
    }

    /// Serialize edges to JSON (thread-safe)
    pub fn edgesToJson(self: *Self, writer: anytype) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        try writer.writeAll("[");

        var edge_iter = self.graph_data.edges.iterator();
        var first = true;
        while (edge_iter.next()) |entry| {
            if (!first) try writer.writeAll(",");
            first = false;

            const e = entry.value_ptr;
            const rel_type = @tagName(e.relationship_type);
            try std.fmt.format(writer,
                \\{{"from":"{s}","to":"{s}","type":"{s}","certainty":{d:.2}}}
            , .{ e.from, e.to, rel_type, e.certainty });
        }

        try writer.writeAll("]");
    }

    /// Serialize complete graph to JSON (thread-safe)
    pub fn graphToJson(self: *Self, writer: anytype) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        try writer.writeAll("{\"vertices\":");
        try self.verticesToJsonUnsafe(writer);
        try writer.writeAll(",\"edges\":");
        try self.edgesToJsonUnsafe(writer);
        try writer.writeAll("}");
    }

    // Unsafe versions (must be called with lock already held)
    fn verticesToJsonUnsafe(self: *Self, writer: anytype) !void {
        try writer.writeAll("[");

        var vertex_iter = self.graph_data.vertices.iterator();
        var first = true;
        while (vertex_iter.next()) |entry| {
            if (!first) try writer.writeAll(",");
            first = false;

            const v = entry.value_ptr;
            try std.fmt.format(writer,
                \\{{"id":"{s}","content":"{s}","x":{d:.2},"y":{d:.2}}}
            , .{ v.id, v.content, v.x, v.y });
        }

        try writer.writeAll("]");
    }

    fn edgesToJsonUnsafe(self: *Self, writer: anytype) !void {
        try writer.writeAll("[");

        var edge_iter = self.graph_data.edges.iterator();
        var first = true;
        while (edge_iter.next()) |entry| {
            if (!first) try writer.writeAll(",");
            first = false;

            const e = entry.value_ptr;
            const rel_type = @tagName(e.relationship_type);
            try std.fmt.format(writer,
                \\{{"from":"{s}","to":"{s}","type":"{s}","certainty":{d:.2}}}
            , .{ e.from, e.to, rel_type, e.certainty });
        }

        try writer.writeAll("]");
    }
};
