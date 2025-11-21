const std = @import("std");
const graph = @import("graph");
const llm = @import("llm");

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
        var edges_updated: usize = 0;
        var edges_skipped: usize = 0;

        for (relationships) |rel| {
            if (vertex_map.get(rel.from_idea)) |from_id| {
                if (vertex_map.get(rel.to_idea)) |to_id| {
                    const initial_count = semantic_graph.edges.items.len;
                    const existing_edge = semantic_graph.findEdge(from_id, to_id, rel.relation_type);
                    const old_certainty = if (existing_edge) |e| e.certainty else 0.0;

                    try semantic_graph.addEdge(from_id, to_id, rel.relation_type, rel.certainty, rel.description);

                    if (semantic_graph.edges.items.len > initial_count) {
                        // New edge was added
                        edges_added += 1;
                        log.debug("Added edge: {s} -> {s} ({s}, certainty: {d:.2})", .{
                            rel.from_idea, rel.to_idea, rel.relation_type.toString(), rel.certainty
                        });
                    } else if (existing_edge != null and old_certainty < rel.certainty) {
                        // Existing edge was updated with higher certainty
                        edges_updated += 1;
                        log.debug("Updated edge: {s} -> {s} ({s}, certainty: {d:.2} -> {d:.2})", .{
                            rel.from_idea, rel.to_idea, rel.relation_type.toString(),
                            old_certainty, rel.certainty
                        });
                    } else {
                        // Duplicate was skipped (same or lower certainty)
                        edges_skipped += 1;
                        log.debug("Skipped duplicate edge: {s} -> {s} ({s}, certainty: {d:.2})", .{
                            rel.from_idea, rel.to_idea, rel.relation_type.toString(), rel.certainty
                        });
                    }
                }
            }
        }

        log.info("Graph constructed: {} vertices, {} edges ({} added, {} updated, {} skipped)", .{
            semantic_graph.vertices.items.len,
            semantic_graph.edges.items.len,
            edges_added,
            edges_updated,
            edges_skipped
        });
    }

    /// Analyzes relationships between a new idea and all existing ideas
    pub fn analyzeNewIdea(
        self: *AnalysisService,
        new_idea: []const u8,
        existing_ideas: []const []const u8,
        semantic_graph: *graph.SemanticGraph,
        llm_client: *llm.LLMClient,
    ) !void {
        log.info("Analyzing new idea against {} existing ideas", .{existing_ideas.len});

        // Add vertex for the new idea
        const new_vertex_id = try semantic_graph.addVertex(new_idea, 0);
        log.debug("Added new vertex with ID: {}", .{new_vertex_id});

        // Build vertex mapping for existing ideas
        var vertex_map = std.StringHashMap(usize).init(self.allocator);
        defer vertex_map.deinit();

        // Map existing ideas to their vertex IDs (they should already exist in the graph)
        for (semantic_graph.vertices.items) |vertex| {
            if (vertex.id != new_vertex_id) {
                try vertex_map.put(vertex.content, vertex.id);
            }
        }

        // Get relationships from LLM - analyze new idea against all existing ideas
        log.debug("Requesting relationship analysis from LLM", .{});
        const new_idea_slice = &[_][]const u8{new_idea};
        const relationships = try llm_client.analyzeRelationships(
            new_idea_slice,
            existing_ideas,
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
        var edges_updated: usize = 0;
        var edges_skipped: usize = 0;

        for (relationships) |rel| {
            // Determine the from and to vertex IDs
            const from_id = if (std.mem.eql(u8, rel.from_idea, new_idea))
                new_vertex_id
            else if (vertex_map.get(rel.from_idea)) |id|
                id
            else
                continue;

            const to_id = if (std.mem.eql(u8, rel.to_idea, new_idea))
                new_vertex_id
            else if (vertex_map.get(rel.to_idea)) |id|
                id
            else
                continue;

            const initial_count = semantic_graph.edges.items.len;
            const existing_edge = semantic_graph.findEdge(from_id, to_id, rel.relation_type);
            const old_certainty = if (existing_edge) |e| e.certainty else 0.0;

            try semantic_graph.addEdge(from_id, to_id, rel.relation_type, rel.certainty, rel.description);

            if (semantic_graph.edges.items.len > initial_count) {
                edges_added += 1;
                log.debug("Added edge: {s} -> {s} ({s}, certainty: {d:.2})", .{
                    rel.from_idea, rel.to_idea, rel.relation_type.toString(), rel.certainty
                });
            } else if (existing_edge != null and old_certainty < rel.certainty) {
                edges_updated += 1;
                log.debug("Updated edge: {s} -> {s} ({s}, certainty: {d:.2} -> {d:.2})", .{
                    rel.from_idea, rel.to_idea, rel.relation_type.toString(),
                    old_certainty, rel.certainty
                });
            } else {
                edges_skipped += 1;
                log.debug("Skipped duplicate edge: {s} -> {s} ({s}, certainty: {d:.2})", .{
                    rel.from_idea, rel.to_idea, rel.relation_type.toString(), rel.certainty
                });
            }
        }

        log.info("Graph updated: {} total vertices, {} total edges ({} added, {} updated, {} skipped)", .{
            semantic_graph.vertices.items.len,
            semantic_graph.edges.items.len,
            edges_added,
            edges_updated,
            edges_skipped
        });
    }
};
