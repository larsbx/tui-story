const std = @import("std");
const graph = @import("graph.zig");
const llm = @import("llm.zig");

const log = std.log.scoped(.analysis_service);

/// Service responsible for orchestrating semantic relationship analysis
pub const AnalysisService = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) AnalysisService {
        return .{ .allocator = allocator };
    }

    /// Analyzes relationships between two groups of ideas and builds a semantic graph
    pub fn analyzeGroups(
        self: *AnalysisService,
        group1_ideas: []const []const u8,
        group2_ideas: []const []const u8,
        semantic_graph: *graph.SemanticGraph,
        llm_client: *llm.LLMClient,
    ) !void {
        log.info("Starting semantic relationship analysis", .{});
        log.debug("Group 1: {} ideas, Group 2: {} ideas", .{ group1_ideas.len, group2_ideas.len });

        // Clear existing graph
        semantic_graph.clear();

        // Build vertex mapping
        var vertex_map = std.StringHashMap(usize).init(self.allocator);
        defer vertex_map.deinit();

        // Add vertices for group 1
        log.debug("Adding {} vertices for Group 1", .{group1_ideas.len});
        for (group1_ideas) |idea| {
            const id = try semantic_graph.addVertex(idea, 0);
            try vertex_map.put(idea, id);
        }

        // Add vertices for group 2
        log.debug("Adding {} vertices for Group 2", .{group2_ideas.len});
        for (group2_ideas) |idea| {
            const id = try semantic_graph.addVertex(idea, 1);
            try vertex_map.put(idea, id);
        }

        // Get relationships from LLM
        log.debug("Requesting relationship analysis from LLM", .{});
        const relationships = try llm_client.analyzeRelationships(
            group1_ideas,
            group2_ideas,
        );
        defer {
            for (relationships) |*rel| {
                var r = rel.*;
                r.deinit(self.allocator);
            }
            self.allocator.free(relationships);
        }

        log.info("LLM analysis complete: {} relationships discovered", .{relationships.len});

        // Add edges to graph
        var edges_added: usize = 0;
        for (relationships) |rel| {
            if (vertex_map.get(rel.from_idea)) |from_id| {
                if (vertex_map.get(rel.to_idea)) |to_id| {
                    try semantic_graph.addEdge(from_id, to_id, rel.relation_type, rel.certainty, rel.description);
                    edges_added += 1;
                    log.debug("Added edge: {s} -> {s} ({s})", .{ rel.from_idea, rel.to_idea, rel.relation_type.toString() });
                }
            }
        }

        log.info("Graph constructed: {} vertices, {} edges", .{ semantic_graph.vertices.items.len, edges_added });
    }
};
