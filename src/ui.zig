const std = @import("std");
const vaxis = @import("vaxis");
const graph = @import("graph");
const llm = @import("llm");
const validation = @import("validation");
const analysis_service = @import("analysis_service");

const log = std.log.scoped(.ui);

pub const UIMode = enum {
    input,
    analyzing,
    viewing_graph,
    help,
};

pub const UIState = struct {
    mode: UIMode,
    ideas: std.ArrayList([]const u8),
    current_input: std.ArrayList(u8),
    selected_edge: ?usize,
    error_message: ?[]const u8,
    allocator: std.mem.Allocator,
    analysis: analysis_service.AnalysisService,

    // TODO: Add unit tests for UIState.init()
    pub fn init() UIState {
        // We'll set the allocator later
        return .{
            .mode = .help,
            .ideas = undefined,
            .current_input = undefined,
            .selected_edge = null,
            .error_message = null,
            .allocator = undefined,
        };
    }

    pub fn initWithAllocator(allocator: std.mem.Allocator) UIState {
        return .{
            .mode = .help,
            .ideas = std.ArrayList([]const u8).init(allocator),
            .current_input = std.ArrayList(u8).init(allocator),
            .selected_edge = null,
            .error_message = null,
            .allocator = allocator,
            .analysis = analysis_service.AnalysisService.init(allocator),
        };
    }

    // TODO: Add unit tests for UIState.handleKey()
    pub fn handleKey(self: *UIState, key: vaxis.Key, g: *graph.SemanticGraph, llm_client: *llm.LLMClient) !void {
        switch (self.mode) {
            .help => {
                if (key.matches('e', .{})) {
                    self.mode = .input;
                    self.current_input.clearRetainingCapacity();
                } else if (key.matches('v', .{}) and g.vertices.items.len > 0) {
                    self.mode = .viewing_graph;
                } else if (key.matches('r', .{})) {
                    try self.reset(g);
                }
            },
            .input => {
                if (key.matches(vaxis.Key.enter, .{})) {
                    if (self.current_input.items.len > 0) {
                        // Validate input before accepting
                        validation.validateIdea(self.current_input.items) catch |err| {
                            self.error_message = switch (err) {
                                error.EmptyInput => "Error: Input is empty",
                                error.InputTooLong => "Error: Input too long (max 1000 chars)",
                                error.InvalidUtf8 => "Error: Invalid UTF-8 encoding",
                                else => "Error: Invalid input",
                            };
                            self.current_input.clearRetainingCapacity();
                            return;
                        };

                        // Sanitize the input
                        const sanitized = try validation.sanitizeInput(self.current_input.items, self.allocator);

                        // Analyze against existing ideas and add to graph
                        try self.analyzeNewIdea(sanitized, g, llm_client);

                        // Store the idea
                        try self.ideas.append(sanitized);

                        self.current_input.clearRetainingCapacity();
                        self.error_message = null; // Clear any previous errors

                        // Show the updated graph
                        self.mode = .viewing_graph;
                    }
                } else if (key.matches(vaxis.Key.escape, .{})) {
                    self.mode = .help;
                    self.current_input.clearRetainingCapacity();
                } else if (key.matches(vaxis.Key.backspace, .{})) {
                    if (self.current_input.items.len > 0) {
                        _ = self.current_input.pop();
                    }
                } else if (key.codepoint != 0 and key.codepoint < 128) {
                    try self.current_input.append(@intCast(key.codepoint));
                }
            },
            .analyzing => {
                // Wait for analysis to complete
            },
            .viewing_graph => {
                if (key.matches(vaxis.Key.escape, .{}) or key.matches('h', .{})) {
                    self.mode = .help;
                } else if (key.matches(vaxis.Key.up, .{})) {
                    if (self.selected_edge) |*idx| {
                        if (idx.* > 0) idx.* -= 1;
                    } else if (g.edges.items.len > 0) {
                        self.selected_edge = 0;
                    }
                } else if (key.matches(vaxis.Key.down, .{})) {
                    if (self.selected_edge) |*idx| {
                        if (idx.* < g.edges.items.len - 1) idx.* += 1;
                    } else if (g.edges.items.len > 0) {
                        self.selected_edge = 0;
                    }
                }
            },
        }
    }

    // TODO: Add unit tests for UIState.analyzeNewIdea()
    fn analyzeNewIdea(self: *UIState, new_idea: []const u8, g: *graph.SemanticGraph, llm_client: *llm.LLMClient) !void {
        // If this is the first idea, just add it to the graph
        if (self.ideas.items.len == 0) {
            _ = try g.addVertex(new_idea, 0);
            return;
        }

        self.mode = .analyzing;

        // Analyze the new idea against all existing ideas
        try self.analysis.analyzeNewIdea(
            new_idea,
            self.ideas.items,
            g,
            llm_client,
        );

        self.mode = .viewing_graph;
    }

    // TODO: Add unit tests for UIState.reset()
    fn reset(self: *UIState, g: *graph.SemanticGraph) !void {
        log.info("Resetting all data", .{});

        // Clear ideas
        for (self.ideas.items) |idea| {
            self.allocator.free(idea);
        }
        self.ideas.clearRetainingCapacity();
        self.current_input.clearRetainingCapacity();

        // Clear graph
        g.clear();

        self.mode = .help;
        self.selected_edge = null;

        log.debug("Reset complete", .{});
    }
};

// TODO: Add unit tests for render()
pub fn render(win: vaxis.Window, state: *UIState, g: *graph.SemanticGraph) !void {
    switch (state.mode) {
        .help => try renderHelp(win, state, g),
        .input => try renderInput(win, state),
        .analyzing => try renderAnalyzing(win),
        .viewing_graph => try renderGraph(win, state, g),
    }
}

// TODO: Add unit tests for renderHelp()
fn renderHelp(win: vaxis.Window, state: *UIState, g: *graph.SemanticGraph) !void {
    const title = "Semantic Relationship Graph Analyzer";
    _ = try win.printSegment(.{ .text = title, .style = .{ .bold = true, .fg = .{ .index = 6 } } }, .{
        .row_offset = 1,
        .col_offset = (win.width / 2) -| (title.len / 2),
    });

    var row: usize = 3;

    const help_text = [_][]const u8{
        "Welcome! Enter ideas one at a time and watch your semantic graph grow.",
        "Each new idea is analyzed against all existing ideas to discover relationships.",
        "",
        "Status:",
    };

    for (help_text) |line| {
        _ = try win.printSegment(.{ .text = line }, .{ .row_offset = row, .col_offset = 2 });
        row += 1;
    }

    // Show status
    const ideas_status = try std.fmt.allocPrint(state.allocator, "  Ideas in graph: {}", .{state.ideas.items.len});
    defer state.allocator.free(ideas_status);
    _ = try win.printSegment(.{ .text = ideas_status, .style = .{ .fg = .{ .index = if (state.ideas.items.len > 0) 2 else 8 } } }, .{ .row_offset = row, .col_offset = 2 });
    row += 1;

    const edges_status = try std.fmt.allocPrint(state.allocator, "  Relationships found: {}", .{g.edges.items.len});
    defer state.allocator.free(edges_status);
    _ = try win.printSegment(.{ .text = edges_status, .style = .{ .fg = .{ .index = if (g.edges.items.len > 0) 2 else 8 } } }, .{ .row_offset = row, .col_offset = 2 });
    row += 2;

    const commands = [_][]const u8{
        "Commands:",
        "  [e] - Enter a new idea",
        "  [v] - View graph (if ideas exist)",
        "  [r] - Reset all data",
        "  [q] - Quit",
    };

    for (commands) |line| {
        _ = try win.printSegment(.{ .text = line }, .{ .row_offset = row, .col_offset = 2 });
        row += 1;
    }

    if (state.ideas.items.len > 0) {
        row += 1;
        _ = try win.printSegment(.{ .text = "Your Ideas:", .style = .{ .bold = true } }, .{ .row_offset = row, .col_offset = 2 });
        row += 1;
        for (state.ideas.items, 0..) |idea, i| {
            const line = try std.fmt.allocPrint(state.allocator, "  {d}. {s}", .{i + 1, idea});
            defer state.allocator.free(line);
            _ = try win.printSegment(.{ .text = line, .style = .{ .fg = .{ .index = 6 } } }, .{ .row_offset = row, .col_offset = 2 });
            row += 1;
            if (row >= win.height - 2) break;
        }
    }
}

// TODO: Add unit tests for renderInput()
fn renderInput(win: vaxis.Window, state: *UIState) !void {
    const title_text = if (state.ideas.items.len == 0)
        "Enter your first idea"
    else
        "Enter another idea";

    _ = try win.printSegment(.{ .text = title_text, .style = .{ .bold = true, .fg = .{ .index = 6 } } }, .{
        .row_offset = 1,
        .col_offset = 2,
    });

    var row: usize = 3;

    if (state.ideas.items.len > 0) {
        const context = try std.fmt.allocPrint(state.allocator, "Current ideas: {}", .{state.ideas.items.len});
        defer state.allocator.free(context);
        _ = try win.printSegment(.{ .text = context, .style = .{ .fg = .{ .index = 8 } } }, .{ .row_offset = row, .col_offset = 2 });
        row += 1;

        const hint = "Your new idea will be compared to all existing ideas";
        _ = try win.printSegment(.{ .text = hint, .style = .{ .fg = .{ .index = 8 } } }, .{ .row_offset = row, .col_offset = 2 });
        row += 2;
    }

    const prompt = try std.fmt.allocPrint(state.allocator, "> {s}_", .{state.current_input.items});
    defer state.allocator.free(prompt);
    _ = try win.printSegment(.{ .text = prompt, .style = .{ .fg = .{ .index = 2 } } }, .{ .row_offset = row, .col_offset = 2 });

    // Show error message if present
    if (state.error_message) |err_msg| {
        row += 2;
        _ = try win.printSegment(.{ .text = err_msg, .style = .{ .fg = .{ .index = 1 }, .bold = true } }, .{
            .row_offset = row,
            .col_offset = 2,
        });
    }

    row = win.height - 3;
    _ = try win.printSegment(.{ .text = "[Enter] Submit idea  [Esc] Back to menu", .style = .{ .fg = .{ .index = 8 } } }, .{
        .row_offset = row,
        .col_offset = 2,
    });
}

// TODO: Add unit tests for renderAnalyzing()
fn renderAnalyzing(win: vaxis.Window) !void {
    const msg = "Analyzing semantic relationships...";
    _ = try win.printSegment(.{ .text = msg, .style = .{ .bold = true, .fg = .{ .index = 3 } } }, .{
        .row_offset = win.height / 2,
        .col_offset = (win.width / 2) -| (msg.len / 2),
    });
}

// TODO: Add unit tests for renderGraph()
fn renderGraph(win: vaxis.Window, state: *UIState, g: *graph.SemanticGraph) !void {
    const title = "Semantic Relationship Graph";
    _ = try win.printSegment(.{ .text = title, .style = .{ .bold = true, .fg = .{ .index = 6 } } }, .{
        .row_offset = 0,
        .col_offset = (win.width / 2) -| (title.len / 2),
    });

    // Calculate layout
    const graph_area_height = win.height - 10;
    g.calculateLayout(@floatFromInt(win.width - 4), @floatFromInt(graph_area_height));

    // Render edges first
    for (g.edges.items, 0..) |edge, idx| {
        const from = g.getVertex(edge.from) orelse continue;
        const to = g.getVertex(edge.to) orelse continue;

        const is_selected = if (state.selected_edge) |sel| sel == idx else false;

        // Draw simple line representation
        const from_row = @as(usize, @intFromFloat(from.y)) + 2;
        const to_row = @as(usize, @intFromFloat(to.y)) + 2;
        const from_col = @as(usize, @intFromFloat(from.x));
        const to_col = @as(usize, @intFromFloat(to.x));

        // Draw relationship symbol in the middle
        if (from_row < win.height and to_row < win.height) {
            const mid_row = (from_row + to_row) / 2;
            const mid_col = (from_col + to_col) / 2;

            if (mid_row < win.height and mid_col < win.width) {
                const symbol = edge.relation_type.getSymbol();
                const style: vaxis.Style = .{
                    .fg = .{ .index = edge.relation_type.getColor() },
                    .reverse = is_selected,
                };
                _ = try win.printSegment(.{ .text = symbol, .style = style }, .{
                    .row_offset = mid_row,
                    .col_offset = mid_col,
                });
            }
        }
    }

    // Render vertices
    for (g.vertices.items) |vertex| {
        const row = @as(usize, @intFromFloat(vertex.y)) + 2;
        const col = @as(usize, @intFromFloat(vertex.x));

        if (row < win.height and col < win.width) {
            const style: vaxis.Style = .{ .fg = .{ .index = 6 }, .bold = true };

            // Truncate long content
            const max_len = 20;
            const display_text = if (vertex.content.len > max_len)
                vertex.content[0..max_len]
            else
                vertex.content;

            _ = try win.printSegment(.{ .text = display_text, .style = style }, .{
                .row_offset = row,
                .col_offset = col -| (display_text.len / 2),
            });
        }
    }

    // Render legend and selected edge info
    var info_row = win.height - 8;
    _ = try win.printSegment(.{ .text = "Relationship Types:", .style = .{ .bold = true } }, .{
        .row_offset = info_row,
        .col_offset = 2,
    });
    info_row += 1;

    const legend = [_]struct { symbol: []const u8, name: []const u8, color: u8 }{
        .{ .symbol = "→", .name = "Implicative", .color = 4 },
        .{ .symbol = "⊆", .name = "Hierarchical", .color = 5 },
        .{ .symbol = "⇒", .name = "Causal", .color = 4 },
        .{ .symbol = "⊥", .name = "Contradictory", .color = 1 },
        .{ .symbol = "≡", .name = "Synonymous", .color = 2 },
        .{ .symbol = "≈", .name = "Analogous", .color = 3 },
    };

    for (legend, 0..) |item, i| {
        const text = try std.fmt.allocPrint(state.allocator, "{s} {s}", .{ item.symbol, item.name });
        defer state.allocator.free(text);
        _ = try win.printSegment(.{ .text = text, .style = .{ .fg = .{ .index = item.color } } }, .{
            .row_offset = info_row,
            .col_offset = 2 + (i % 3) * 25,
        });
        if ((i + 1) % 3 == 0) info_row += 1;
    }

    // Show selected edge details
    if (state.selected_edge) |idx| {
        if (idx < g.edges.items.len) {
            const edge = g.edges.items[idx];
            info_row = win.height - 2;

            const from = g.getVertex(edge.from);
            const to = g.getVertex(edge.to);

            if (from != null and to != null) {
                const detail = try std.fmt.allocPrint(
                    state.allocator,
                    "Selected: {s} {s} {s} (certainty: {d:.2})",
                    .{ from.?.content, edge.relation_type.getSymbol(), to.?.content, edge.certainty },
                );
                defer state.allocator.free(detail);
                _ = try win.printSegment(.{ .text = detail, .style = .{ .reverse = true } }, .{
                    .row_offset = info_row,
                    .col_offset = 2,
                });
            }
        }
    }

    // Controls
    const controls = "[↑↓] Select edge  [Esc/h] Back to menu  [q] Quit";
    _ = try win.printSegment(.{ .text = controls, .style = .{ .fg = .{ .index = 8 } } }, .{
        .row_offset = win.height - 1,
        .col_offset = 2,
    });
}
