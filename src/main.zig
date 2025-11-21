const std = @import("std");
const vaxis = @import("vaxis");
const graph = @import("graph.zig");
const llm = @import("llm.zig");
const ui = @import("ui.zig");
const mcp_server = @import("mcp_server.zig");
const analysis_service = @import("analysis_service.zig");

const log = std.log.scoped(.semantic_graph);

const Event = union(enum) {
    key_press: vaxis.Key,
    winsize: vaxis.Winsize,
};

const App = struct {
    allocator: std.mem.Allocator,
    vx: *vaxis.Vaxis,
    tty: vaxis.Tty,
    graph_data: graph.SemanticGraph,
    llm_client: llm.LLMClient,
    ui_state: ui.UIState,
    should_quit: bool,

    fn init(allocator: std.mem.Allocator) !App {
        log.info("Initializing Semantic Graph TUI application", .{});

        var vx = try allocator.create(vaxis.Vaxis);
        vx.* = try vaxis.init(allocator, .{});

        log.debug("Terminal UI initialized successfully", .{});

        return App{
            .allocator = allocator,
            .vx = vx,
            .tty = try vaxis.Tty.init(),
            .graph_data = graph.SemanticGraph.init(allocator),
            .llm_client = llm.LLMClient.init(allocator),
            .ui_state = ui.UIState.initWithAllocator(allocator),
            .should_quit = false,
        };
    }

    fn deinit(self: *App) void {
        log.info("Shutting down application", .{});

        // Clean up UI state
        for (self.ui_state.group1_ideas.items) |idea| {
            self.allocator.free(idea);
        }
        for (self.ui_state.group2_ideas.items) |idea| {
            self.allocator.free(idea);
        }
        self.ui_state.group1_ideas.deinit();
        self.ui_state.group2_ideas.deinit();
        self.ui_state.current_input.deinit();

        self.graph_data.deinit();
        self.llm_client.deinit();
        self.vx.deinit(self.allocator);
        self.allocator.destroy(self.vx);
        self.tty.deinit();

        log.debug("Application cleanup completed", .{});
    }

    fn run(self: *App) !void {
        var loop: vaxis.Loop(Event) = .{
            .tty = &self.tty,
            .vaxis = self.vx,
        };
        try loop.init();

        try loop.start();
        defer loop.stop();

        try self.vx.enterAltScreen(self.tty.anyWriter());
        try self.vx.queryTerminal(self.tty.anyWriter(), 1 * std.time.ns_per_s);

        while (!self.should_quit) {
            loop.pollEvent();
            while (loop.tryEvent()) |event| {
                try self.handleEvent(event);
            }

            try self.render();
            try self.vx.render(self.tty.anyWriter());
        }

        try self.vx.exitAltScreen(self.tty.anyWriter());
    }

    fn handleEvent(self: *App, event: Event) !void {
        switch (event) {
            .key_press => |key| {
                if (key.matches('c', .{ .ctrl = true })) {
                    log.info("Received quit signal (Ctrl+C)", .{});
                    self.should_quit = true;
                } else if (key.matches('q', .{})) {
                    log.info("Received quit signal (q)", .{});
                    self.should_quit = true;
                } else {
                    try self.ui_state.handleKey(key, &self.graph_data, &self.llm_client);
                }
            },
            .winsize => |ws| {
                log.debug("Terminal resized: {}x{}", .{ ws.cols, ws.rows });
                try self.vx.resize(self.allocator, self.tty.anyWriter(), ws);
            },
        }
    }

    fn render(self: *App) !void {
        const win = self.vx.window();
        win.clear();

        try ui.render(win, &self.ui_state, &self.graph_data);
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            log.err("Memory leak detected on shutdown", .{});
        }
    }
    const allocator = gpa.allocator();

    // Parse command line arguments
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    // Skip program name
    _ = args.skip();

    var mcp_mode = false;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--mcp") or std.mem.eql(u8, arg, "-m")) {
            mcp_mode = true;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            const stdout = std.io.getStdOut().writer();
            try stdout.print(
                \\Semantic Relationship Graph TUI
                \\
                \\Usage: semantic-graph-tui [OPTIONS]
                \\
                \\Options:
                \\  --mcp, -m    Run in headless MCP (Model Context Protocol) server mode
                \\  --help, -h   Show this help message
                \\
                \\Environment Variables:
                \\  LLM_PROVIDER       Provider: anthropic, openai, custom (default: anthropic)
                \\  LLM_MODEL          Model name (default: claude-3-5-sonnet-20241022)
                \\  LLM_API_ENDPOINT   Custom API endpoint (for custom provider)
                \\  ANTHROPIC_API_KEY  Anthropic API key
                \\  OPENAI_API_KEY     OpenAI API key
                \\
                \\MCP Server Mode:
                \\  In MCP mode, the application runs as a headless JSON-RPC 2.0 server
                \\  communicating over stdio. This enables integration with Claude and
                \\  other LLM applications via the Model Context Protocol.
                \\
                \\  Available MCP tools:
                \\    - add_idea: Add a concept to the graph
                \\    - analyze_idea: Analyze relationships with existing ideas
                \\    - get_graph: Retrieve the complete graph state
                \\    - list_ideas: List all concepts
                \\    - reset_graph: Clear all data
                \\
                \\  Available MCP resources:
                \\    - graph://state: Complete graph JSON
                \\    - graph://vertices: List of vertices
                \\    - graph://edges: List of edges
                \\
            , .{});
            return;
        }
    }

    if (mcp_mode) {
        log.info("Starting in MCP server mode", .{});
        try runMCPServer(allocator);
    } else {
        log.info("Starting Semantic Relationship Graph TUI", .{});
        try runTUI(allocator);
    }

    log.info("Application exited successfully", .{});
}

fn runTUI(allocator: std.mem.Allocator) !void {
    var app = try App.init(allocator) catch |err| {
        log.err("Failed to initialize application: {}", .{err});
        return err;
    };
    defer app.deinit();

    try app.run() catch |err| {
        log.err("Application error: {}", .{err});
        return err;
    };
}

fn runMCPServer(allocator: std.mem.Allocator) !void {
    var graph_data = graph.SemanticGraph.init(allocator);
    defer graph_data.deinit();

    var llm_client = llm.LLMClient.init(allocator);
    defer llm_client.deinit();

    var analysis_svc = analysis_service.AnalysisService.init(allocator, &graph_data, &llm_client);

    var server = mcp_server.MCPServer.init(allocator, &graph_data, &llm_client, &analysis_svc);

    try server.run() catch |err| {
        log.err("MCP Server error: {}", .{err});
        return err;
    };
}
