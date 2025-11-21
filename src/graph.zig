const std = @import("std");
const validation = @import("validation");

pub const RelationType = enum {
    contradictory,
    implicative,
    hierarchical,
    evolutionary,
    analogous,
    synonymous,
    antonymous,
    part_whole,
    causal,

    pub fn toString(self: RelationType) []const u8 {
        return switch (self) {
            .contradictory => "CONTRADICTORY",
            .implicative => "IMPLICATIVE",
            .hierarchical => "HIERARCHICAL",
            .evolutionary => "EVOLUTIONARY",
            .analogous => "ANALOGOUS",
            .synonymous => "SYNONYMOUS",
            .antonymous => "ANTONYMOUS",
            .part_whole => "PART_WHOLE",
            .causal => "CAUSAL",
        };
    }

    pub fn fromString(str: []const u8) !RelationType {
        if (std.mem.eql(u8, str, "CONTRADICTORY")) return .contradictory;
        if (std.mem.eql(u8, str, "IMPLICATIVE")) return .implicative;
        if (std.mem.eql(u8, str, "HIERARCHICAL")) return .hierarchical;
        if (std.mem.eql(u8, str, "EVOLUTIONARY")) return .evolutionary;
        if (std.mem.eql(u8, str, "ANALOGOUS")) return .analogous;
        if (std.mem.eql(u8, str, "SYNONYMOUS")) return .synonymous;
        if (std.mem.eql(u8, str, "ANTONYMOUS")) return .antonymous;
        if (std.mem.eql(u8, str, "PART_WHOLE")) return .part_whole;
        if (std.mem.eql(u8, str, "CAUSAL")) return .causal;
        return error.UnknownRelationType;
    }

    // TODO(UX-MEDIUM): Add ASCII fallback mode for terminal compatibility
    // See: docs/UX_REVIEW.md - Principle #5 (Accessibility as Foundation)
    // Current: Unicode symbols may not render correctly on all terminals
    // Needed: Add getSymbolAscii() or ascii_mode config option
    // Effort: 3 hours | Priority: MEDIUM
    // Implementation:
    //   Add config: ascii_mode: bool (default false)
    //   ASCII mappings: ⊥→"!=" →→"->" ⊆→"⊂" ⟿→"~>" ≈→"~" ≡→"=" ≠→"!=" ∈→"∈" ⇒→"=>"
    //   Alternative: Create getSymbolAscii() returning simpler ASCII art
    pub fn getSymbol(self: RelationType) []const u8 {
        return switch (self) {
            .contradictory => "⊥",
            .implicative => "→",
            .hierarchical => "⊆",
            .evolutionary => "⟿",
            .analogous => "≈",
            .synonymous => "≡",
            .antonymous => "≠",
            .part_whole => "∈",
            .causal => "⇒",
        };
    }

    pub fn getColor(self: RelationType) u8 {
        return switch (self) {
            .contradictory => 1, // red
            .implicative => 4, // blue
            .hierarchical => 5, // magenta
            .evolutionary => 6, // cyan
            .analogous => 3, // yellow
            .synonymous => 2, // green
            .antonymous => 1, // red
            .part_whole => 5, // magenta
            .causal => 4, // blue
        };
    }
};

pub const Vertex = struct {
    id: usize,
    content: []const u8,
    x: f32, // For graph layout
    y: f32,
    group: usize, // 0 or 1 for the two idea groups

    pub fn deinit(self: *Vertex, allocator: std.mem.Allocator) void {
        allocator.free(self.content);
    }
};

pub const Edge = struct {
    from: usize, // Vertex ID
    to: usize, // Vertex ID
    relation_type: RelationType,
    certainty: f32,
    description: []const u8,

    pub fn deinit(self: *Edge, allocator: std.mem.Allocator) void {
        allocator.free(self.description);
    }
};

pub const SemanticGraph = struct {
    allocator: std.mem.Allocator,
    vertices: std.ArrayList(Vertex),
    edges: std.ArrayList(Edge),
    next_id: usize,

    pub fn init(allocator: std.mem.Allocator) SemanticGraph {
        return .{
            .allocator = allocator,
            .vertices = std.ArrayList(Vertex).init(allocator),
            .edges = std.ArrayList(Edge).init(allocator),
            .next_id = 0,
        };
    }

    pub fn deinit(self: *SemanticGraph) void {
        for (self.vertices.items) |*vertex| {
            vertex.deinit(self.allocator);
        }
        for (self.edges.items) |*edge| {
            edge.deinit(self.allocator);
        }
        self.vertices.deinit();
        self.edges.deinit();
    }

    pub fn addVertex(self: *SemanticGraph, content: []const u8, group: usize) !usize {
        // Validate inputs
        try validation.validateVertexContent(content);
        try validation.validateGroup(group);

        const id = self.next_id;
        self.next_id += 1;

        const content_copy = try self.allocator.dupe(u8, content);

        try self.vertices.append(.{
            .id = id,
            .content = content_copy,
            .x = 0.0,
            .y = 0.0,
            .group = group,
        });

        return id;
    }

    pub fn addEdge(self: *SemanticGraph, from: usize, to: usize, relation_type: RelationType, certainty: f32, description: []const u8) !void {
        // Check for existing edge with same type
        if (self.findEdge(from, to, relation_type)) |existing_edge| {
            // Update existing edge if new certainty is higher
            if (certainty > existing_edge.certainty) {
                self.allocator.free(existing_edge.description);
                existing_edge.certainty = certainty;
                existing_edge.description = try self.allocator.dupe(u8, description);
            }
            // Otherwise, silently skip duplicate
            return;
        }

        // Add new edge
        const desc_copy = try self.allocator.dupe(u8, description);
        try self.edges.append(.{
            .from = from,
            .to = to,
            .relation_type = relation_type,
            .certainty = certainty,
            .description = desc_copy,
        });
    }

    pub fn getVertex(self: *SemanticGraph, id: usize) ?*Vertex {
        for (self.vertices.items) |*vertex| {
            if (vertex.id == id) return vertex;
        }
        return null;
    }

    /// Check if a specific edge exists between two vertices
    pub fn hasEdge(self: *SemanticGraph, from: usize, to: usize, relation_type: RelationType) bool {
        for (self.edges.items) |edge| {
            if (edge.from == from and edge.to == to and edge.relation_type == relation_type) {
                return true;
            }
        }
        return false;
    }

    /// Get all edges between two vertices (caller owns returned slice)
    pub fn getEdgesBetween(self: *SemanticGraph, from: usize, to: usize) ![]Edge {
        var result = std.ArrayList(Edge).init(self.allocator);
        for (self.edges.items) |edge| {
            if (edge.from == from and edge.to == to) {
                try result.append(edge);
            }
        }
        return result.toOwnedSlice();
    }

    /// Find a specific edge between two vertices
    pub fn findEdge(self: *SemanticGraph, from: usize, to: usize, relation_type: RelationType) ?*Edge {
        for (self.edges.items) |*edge| {
            if (edge.from == from and edge.to == to and edge.relation_type == relation_type) {
                return edge;
            }
        }
        return null;
    }

    pub fn clear(self: *SemanticGraph) void {
        for (self.vertices.items) |*vertex| {
            vertex.deinit(self.allocator);
        }
        for (self.edges.items) |*edge| {
            edge.deinit(self.allocator);
        }
        self.vertices.clearRetainingCapacity();
        self.edges.clearRetainingCapacity();
        self.next_id = 0;
    }

    // Simple force-directed layout algorithm
    pub fn calculateLayout(self: *SemanticGraph, width: f32, height: f32) void {
        if (self.vertices.items.len == 0) return;

        // Initial positioning - split into two groups
        var group0_count: usize = 0;
        var group1_count: usize = 0;
        for (self.vertices.items) |vertex| {
            if (vertex.group == 0) group0_count += 1 else group1_count += 1;
        }

        var g0_idx: usize = 0;
        var g1_idx: usize = 0;

        for (self.vertices.items) |*vertex| {
            if (vertex.group == 0) {
                vertex.x = width * 0.25;
                vertex.y = height * (@as(f32, @floatFromInt(g0_idx)) + 1.0) / (@as(f32, @floatFromInt(group0_count)) + 1.0);
                g0_idx += 1;
            } else {
                vertex.x = width * 0.75;
                vertex.y = height * (@as(f32, @floatFromInt(g1_idx)) + 1.0) / (@as(f32, @floatFromInt(group1_count)) + 1.0);
                g1_idx += 1;
            }
        }

        // Simple force-directed adjustment (few iterations)
        const iterations = 50;
        const k = @sqrt(width * height / @as(f32, @floatFromInt(self.vertices.items.len)));
        const t = k / 10.0;

        var iter: usize = 0;
        while (iter < iterations) : (iter += 1) {
            // Calculate repulsive forces between all vertices
            for (self.vertices.items) |*v1| {
                var fx: f32 = 0.0;
                var fy: f32 = 0.0;

                for (self.vertices.items) |*v2| {
                    if (v1.id == v2.id) continue;

                    const dx = v1.x - v2.x;
                    const dy = v1.y - v2.y;
                    const dist = @sqrt(dx * dx + dy * dy) + 0.01;

                    const repulsion = k * k / dist;
                    fx += (dx / dist) * repulsion;
                    fy += (dy / dist) * repulsion;
                }

                // Constrain to group side
                const target_x = if (v1.group == 0) width * 0.25 else width * 0.75;
                fx += (target_x - v1.x) * 0.1;

                v1.x += fx * t * 0.01;
                v1.y += fy * t * 0.01;

                // Keep within bounds
                v1.x = @max(10.0, @min(width - 10.0, v1.x));
                v1.y = @max(5.0, @min(height - 5.0, v1.y));
            }
        }
    }
};
