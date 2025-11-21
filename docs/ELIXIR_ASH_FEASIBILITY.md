# Feasibility Study: Porting Semantic Graph TUI to Elixir/Ash Framework

**Date**: 2025-11-21
**Current Stack**: Zig + libvaxis
**Target Stack**: Elixir + Ash Framework
**Prepared by**: Architecture Analysis

---

## Executive Summary

**Recommendation**: ✅ **HIGHLY FEASIBLE - TUI Experience Can Be Maintained**

Porting this Zig-based semantic graph application to Elixir with Ash is highly feasible and can maintain the terminal UI experience using **Ratatouille**. Elixir/Ash provides excellent concurrency, and Ratatouille offers similar TUI capabilities to libvaxis.

**Key Findings**:
- **High Compatibility**: MCP HTTP server, LLM integration, concurrent access patterns, **TUI via Ratatouille**
- **Medium Compatibility**: Graph data modeling, relationship analysis workflows
- **Estimated Effort**: 5-7 weeks (single developer, reduced from initial estimate)

---

## 1. Current Zig Architecture Analysis

### 1.1 Core Components

```
┌─────────────────────────────────────────────────────┐
│                   main.zig                          │
│  ┌──────────┐  ┌──────────┐  ┌─────────────────┐  │
│  │ TUI Mode │  │ MCP Stdio│  │ MCP HTTP Server │  │
│  └────┬─────┘  └────┬─────┘  └────────┬────────┘  │
└───────┼─────────────┼─────────────────┼────────────┘
        │             │                 │
        ▼             ▼                 ▼
   ┌─────────────────────────────────────────┐
   │         SemanticGraph (graph.zig)       │
   │  - Vertices (ideas/concepts)            │
   │  - Edges (relationships)                │
   │  - RelationType enum (9 types)          │
   │  - Layout calculation (force-directed)  │
   └──────────────┬──────────────────────────┘
                  │
        ┌─────────┴─────────┐
        ▼                   ▼
┌──────────────────┐  ┌──────────────────┐
│ ThreadSafeGraph  │  │  AnalysisService │
│ - Mutex wrapping │  │  - LLM analysis  │
│ - JSON export    │  │  - Relationship  │
│ - Concurrent ops │  │    discovery     │
└──────────────────┘  └─────────┬────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │  LLMClient      │
                       │ - Anthropic API │
                       │ - OpenAI API    │
                       │ - Custom APIs   │
                       │ - Retry logic   │
                       └─────────────────┘
```

### 1.2 Concurrency Model

**Zig Approach**:
- `std.Thread.Mutex` for graph synchronization (src/thread_safe_graph.zig:9)
- Thread spawning for HTTP requests (src/mcp_server_concurrent.zig:64)
- Atomic bool for shutdown signaling (src/mcp_server_concurrent.zig:16)
- Manual lock/unlock patterns

### 1.3 Data Structures

**Core Types**:
```zig
// Vertex (graph.zig:80-90)
Vertex {
    id: usize,
    content: []const u8,
    x: f32, y: f32,  // Layout coordinates
    group: usize     // 0 or 1 for bipartite grouping
}

// Edge (graph.zig:92-102)
Edge {
    from: usize, to: usize,
    relation_type: RelationType,
    certainty: f32,
    description: []const u8
}

// RelationType (graph.zig:4-78)
enum { contradictory, implicative, hierarchical,
       evolutionary, analogous, synonymous,
       antonymous, part_whole, causal }
```

---

## 2. Elixir/Ash Framework Mapping

### 2.1 What Ash Provides

**Ash Framework** is a declarative, resource-oriented framework for building Elixir applications:
- **Resources**: Domain entities with CRUD operations
- **Actions**: Create, read, update, destroy, custom actions
- **Relationships**: Belongs to, has many, many to many
- **API Modules**: Automatic REST/GraphQL/JSON API generation
- **Authorization**: Policy-based access control
- **Aggregates**: Computed fields and statistics

### 2.2 Component Mapping

| Zig Component | Elixir/Ash Equivalent | Complexity | Notes |
|---------------|----------------------|------------|-------|
| **SemanticGraph** | Ash.Resource | Medium | Graph as resource, but needs custom actions |
| **Vertex** | Ash.Resource (Vertex) | Low | Natural mapping with attributes |
| **Edge** | Ash.Resource (Relationship) | Medium | Many-to-many with metadata |
| **ThreadSafeGraph** | GenServer state | Low | OTP processes handle concurrency |
| **LLMClient** | Tesla/Req HTTP client | Low | Similar retry/timeout patterns |
| **AnalysisService** | Ash.Action + Task | Medium | Custom action triggering async work |
| **MCP HTTP Server** | Phoenix + Plug | Low | Standard HTTP handling |
| **MCP Stdio Server** | Port/Task | Medium | Less common, needs custom impl |
| **TUI (libvaxis)** | Phoenix LiveView | High | Complete paradigm shift |
| **Force-directed layout** | Custom module | Low | Port algorithm to Elixir |

### 2.3 Proposed Elixir Architecture

```
┌──────────────────────────────────────────────────────┐
│              Phoenix Application                      │
│  ┌────────────┐  ┌─────────────┐  ┌──────────────┐  │
│  │ LiveView   │  │ MCP HTTP    │  │ MCP Stdio    │  │
│  │ (Web TUI)  │  │ Endpoint    │  │ Port Handler │  │
│  └─────┬──────┘  └──────┬──────┘  └──────┬───────┘  │
└────────┼─────────────────┼─────────────────┼─────────┘
         │                 │                 │
         ▼                 ▼                 ▼
    ┌─────────────────────────────────────────────┐
    │           Ash API Layer                     │
    │  - GraphAPI.Vertex (Ash.Resource)          │
    │  - GraphAPI.Edge (Ash.Resource)            │
    │  - GraphAPI.Graph (Ash.Resource)           │
    │  - Custom Actions: analyze_idea, etc.      │
    └──────────────────┬──────────────────────────┘
                       │
         ┌─────────────┴─────────────┐
         ▼                           ▼
    ┌──────────────┐        ┌─────────────────┐
    │ GraphManager │        │ AnalysisWorker  │
    │  GenServer   │        │   GenServer     │
    │ - ETS cache  │        │ - LLM calls     │
    │ - Layout calc│        │ - Task.async    │
    └──────────────┘        └────────┬────────┘
                                     │
                                     ▼
                            ┌─────────────────┐
                            │  LLM.Client     │
                            │ - Tesla/Req     │
                            │ - Retry w/expo  │
                            │ - Circuit break │
                            └─────────────────┘
```

---

## 3. Detailed Component Analysis

### 3.1 Data Modeling in Ash

#### ✅ Vertex Resource (GOOD FIT)

```elixir
defmodule GraphAPI.Vertex do
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,  # In-memory like Zig
    extensions: [AshJsonApi.Resource]

  attributes do
    uuid_primary_key :id
    attribute :content, :string, allow_nil?: false
    attribute :x, :float, default: 0.0
    attribute :y, :float, default: 0.0
    attribute :group, :integer, default: 0

    timestamps()
  end

  actions do
    defaults [:create, :read, :update, :destroy]

    create :add_idea do
      accept [:content, :group]
      validate present(:content)
      validate string_length(:content, max: 1000)
    end
  end

  relationships do
    has_many :outgoing_edges, GraphAPI.Edge,
      destination_attribute: :from_vertex_id
    has_many :incoming_edges, GraphAPI.Edge,
      destination_attribute: :to_vertex_id
  end
end
```

**Analysis**: Natural mapping, Ash handles validation, timestamps, relationships automatically.

#### ⚠️ Edge Resource (MEDIUM FIT)

```elixir
defmodule GraphAPI.Edge do
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key :id
    attribute :relation_type, :atom do
      constraints one_of: [
        :contradictory, :implicative, :hierarchical,
        :evolutionary, :analogous, :synonymous,
        :antonymous, :part_whole, :causal
      ]
    end
    attribute :certainty, :float
    attribute :description, :string

    timestamps()
  end

  relationships do
    belongs_to :from_vertex, GraphAPI.Vertex
    belongs_to :to_vertex, GraphAPI.Vertex
  end

  actions do
    create :add_relationship do
      accept [:from_vertex_id, :to_vertex_id,
              :relation_type, :certainty, :description]

      # Custom logic: update if exists with higher certainty
      change fn changeset, _context ->
        # Ash allows custom change functions
        handle_duplicate_edge(changeset)
      end
    end
  end
end
```

**Challenge**: Zig code updates existing edges if certainty is higher (graph.zig:151-162). Need custom Ash change logic.

#### ⚠️ Graph Analysis Actions (CUSTOM LOGIC NEEDED)

```elixir
defmodule GraphAPI.Graph do
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets

  actions do
    # Custom action for relationship analysis
    action :analyze_new_idea, :struct do
      argument :content, :string, allow_nil?: false

      run fn input, _context ->
        # 1. Get all existing vertices
        existing_ideas = GraphAPI.Vertex |> Ash.read!()

        # 2. Call LLM service (async Task)
        task = Task.async(fn ->
          LLM.Client.analyze_relationships(
            [input.content],
            Enum.map(existing_ideas, & &1.content)
          )
        end)

        # 3. Create new vertex
        {:ok, vertex} = GraphAPI.Vertex
          |> Ash.Changeset.for_create(:add_idea, %{content: input.content})
          |> Ash.create()

        # 4. Wait for LLM results
        relationships = Task.await(task, 30_000)

        # 5. Create edges
        Enum.each(relationships, fn rel ->
          create_edge_from_relationship(vertex, rel, existing_ideas)
        end)

        {:ok, %{vertex: vertex, relationships_found: length(relationships)}}
      end
    end

    action :reset_graph, :struct do
      run fn _input, _context ->
        GraphAPI.Vertex |> Ash.destroy_all!()
        GraphAPI.Edge |> Ash.destroy_all!()
        {:ok, %{message: "Graph cleared"}}
      end
    end
  end
end
```

**Challenge**: Ash actions are designed for single-resource operations. Complex multi-step workflows (analyze → create vertex → create edges) require custom logic.

### 3.2 Concurrency: Zig Mutex vs Elixir OTP

#### Zig Pattern (Current)
```zig
// src/thread_safe_graph.zig:26-30
pub fn addVertex(self: *Self, content: []const u8) ![]const u8 {
    self.mutex.lock();
    defer self.mutex.unlock();
    return try self.graph_data.addVertex(content);
}
```

#### Elixir Pattern (Proposed)
```elixir
defmodule GraphManager do
  use GenServer

  # State holds the graph in ETS
  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  # Concurrent calls are serialized by GenServer
  def add_vertex(content) do
    GenServer.call(__MODULE__, {:add_vertex, content})
  end

  def handle_call({:add_vertex, content}, _from, state) do
    # Single-threaded execution, no mutex needed
    {:ok, vertex} = GraphAPI.Vertex
      |> Ash.Changeset.for_create(:add_idea, %{content: content})
      |> Ash.create()

    {:reply, {:ok, vertex}, state}
  end
end
```

**Advantages of Elixir**:
- ✅ No manual lock/unlock (GenServer handles it)
- ✅ Built-in timeout handling
- ✅ Process isolation (crashes don't affect other processes)
- ✅ Backpressure via message queue

**Disadvantages**:
- ⚠️ Slightly higher latency per operation (message passing overhead)
- ⚠️ Need to design supervision tree

### 3.3 HTTP MCP Server

#### Zig Implementation (Current)
- Uses `std.http.Server` (mcp_server_concurrent.zig:43-67)
- Spawns thread per request (line 64)
- Manual JSON-RPC parsing

#### Elixir/Phoenix Implementation (Proposed)

```elixir
# lib/app_web/router.ex
defmodule AppWeb.Router do
  use Phoenix.Router

  pipeline :mcp do
    plug :accepts, ["json"]
    plug AppWeb.Plugs.JSONRPC  # Custom JSON-RPC 2.0 handler
  end

  scope "/mcp", AppWeb do
    pipe_through :mcp

    post "/", MCPController, :handle_request
  end
end

# lib/app_web/controllers/mcp_controller.ex
defmodule AppWeb.MCPController do
  use AppWeb, :controller

  def handle_request(conn, %{"method" => method, "params" => params, "id" => id}) do
    result = case method do
      "tools/list" -> MCPHandlers.list_tools()
      "tools/call" -> MCPHandlers.call_tool(params)
      "resources/list" -> MCPHandlers.list_resources()
      "resources/read" -> MCPHandlers.read_resource(params)
      _ -> {:error, -32601, "Method not found"}
    end

    json(conn, format_jsonrpc_response(result, id))
  end
end
```

**Advantages**:
- ✅ Phoenix handles concurrency automatically (thousands of connections)
- ✅ Built-in JSON encoding/decoding
- ✅ WebSocket support for future real-time updates
- ✅ Easier testing with `Phoenix.ConnTest`

### 3.4 LLM Integration

#### Current Zig Implementation
- Manual HTTP client (llm.zig:192-271)
- Retry with exponential backoff (llm.zig:163-189)
- Multi-provider support (Anthropic, OpenAI, custom)

#### Elixir Implementation (Proposed)

```elixir
defmodule LLM.Client do
  use Tesla

  plug Tesla.Middleware.BaseUrl, get_api_endpoint()
  plug Tesla.Middleware.JSON
  plug Tesla.Middleware.Headers, [{"content-type", "application/json"}]
  plug Tesla.Middleware.Retry,
    delay: 1000,
    max_retries: 3,
    max_delay: 16_000,
    should_retry: fn
      {:ok, %{status: status}} when status in 500..599 -> true
      {:ok, _} -> false
      {:error, _} -> true
    end
  plug Tesla.Middleware.Timeout, timeout: 30_000

  def analyze_relationships(group1, group2) do
    prompt = build_prompt(group1, group2)

    case post("/messages", build_request_body(prompt)) do
      {:ok, %{status: 200, body: body}} ->
        extract_relationships(body)

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_request_body(prompt) do
    %{
      model: get_model(),
      max_tokens: 4096,
      messages: [
        %{role: "user", content: prompt}
      ]
    }
  end
end
```

**Advantages**:
- ✅ Tesla provides retry, timeout, middleware out-of-box
- ✅ Cleaner error handling with pattern matching
- ✅ Easy to swap HTTP client (Req, Finch, HTTPoison)

### 3.5 TUI Interface: ✅ Ratatouille Maintains Terminal Experience

#### Recommended: Ratatouille (Elixir TUI Library)

**Good News**: Elixir has **Ratatouille**, a mature TUI library that can replicate your current terminal interface experience!

**Ratatouille** follows the Elm Architecture (similar to Redux) and provides:
- Terminal rendering with colors, borders, panels
- Keyboard/mouse event handling
- Layout system (rows, columns, tables)
- Built on ExTermbox (Elixir bindings to Termbox)
- Active maintenance and community support

#### Complete UI Mode Implementation

Here's how your current Zig UI modes map directly to Ratatouille:

```elixir
defmodule SemanticGraphTUI do
  @behaviour Ratatouille.App

  import Ratatouille.View
  import Ratatouille.Constants, only: [key: 1, color: 1]

  # Matches ui.zig:10-19
  defmodule State do
    defstruct mode: :help,
              ideas: [],
              current_input: "",
              selected_edge: nil,
              error_message: nil,
              graph: nil,
              analyzing: false
  end

  @impl true
  def init(_context) do
    %State{
      graph: GraphAPI.list_all_vertices()
    }
  end

  # Event handling - matches ui.zig:63-160
  @impl true
  def update(model, msg) do
    case {model.mode, msg} do
      # Help mode (ui.zig:65-78)
      {:help, {:event, %{ch: ?e}}} ->
        %{model | mode: :input, current_input: "", error_message: nil}

      {:help, {:event, %{ch: ?v}}} when length(model.ideas) > 0 ->
        %{model | mode: :viewing_graph, selected_edge: nil}

      {:help, {:event, %{ch: ?r}}} ->
        reset_graph()
        %{model | ideas: [], graph: nil, mode: :help}

      {:help, {:event, %{ch: ?q}}} ->
        Ratatouille.Runtime.shutdown()
        model

      # Input mode (ui.zig:80-119)
      {:input, {:event, %{key: key(:enter)}}} when model.current_input != "" ->
        case validate_and_analyze(model.current_input) do
          {:ok, result} ->
            %{model |
              mode: :viewing_graph,
              ideas: [model.current_input | model.ideas],
              current_input: "",
              graph: result,
              error_message: nil
            }

          {:error, message} ->
            %{model | error_message: message, current_input: ""}
        end

      {:input, {:event, %{key: key(:esc)}}} ->
        %{model | mode: :help, current_input: "", error_message: nil}

      {:input, {:event, %{key: key(:backspace)}}} ->
        %{model | current_input: String.slice(model.current_input, 0..-2//1)}

      {:input, {:event, %{ch: ch}}} when ch >= 32 and ch < 127 ->
        %{model | current_input: model.current_input <> <<ch::utf8>>}

      # Viewing graph mode (ui.zig:130-158)
      {:viewing_graph, {:event, %{key: key(:esc)}}} ->
        %{model | mode: :help}

      {:viewing_graph, {:event, %{ch: ?h}}} ->
        %{model | mode: :help}

      {:viewing_graph, {:event, %{key: key(:arrow_up)}}} ->
        %{model | selected_edge: move_selection(model.selected_edge, :up, model.graph)}

      {:viewing_graph, {:event, %{key: key(:arrow_down)}}} ->
        %{model | selected_edge: move_selection(model.selected_edge, :down, model.graph)}

      _ ->
        model
    end
  end

  # Rendering - matches ui.zig:215-222
  @impl true
  def render(model) do
    case model.mode do
      :help -> render_help(model)
      :input -> render_input(model)
      :analyzing -> render_analyzing(model)
      :viewing_graph -> render_graph(model)
    end
  end

  # Help screen - matches ui.zig:225-288
  defp render_help(model) do
    view do
      panel title: "Semantic Relationship Graph Analyzer", height: :fill do
        label(content: "")
        label(content: "Welcome! Enter ideas one at a time and watch your semantic graph grow.")
        label(content: "Each new idea is analyzed against all existing ideas to discover relationships.")
        label(content: "")

        label(content: "Status:", attributes: [color(:yellow)])
        label(
          content: "  Ideas in graph: #{length(model.ideas)}",
          attributes: [color(if length(model.ideas) > 0, do: :green, else: :white)]
        )

        edges_count = if model.graph, do: length(model.graph.edges), else: 0
        label(
          content: "  Relationships found: #{edges_count}",
          attributes: [color(if edges_count > 0, do: :green, else: :white)]
        )

        label(content: "")
        label(content: "Commands:", attributes: [color(:yellow)])
        label(content: "  [e] - Enter a new idea")
        label(content: "  [v] - View graph (if ideas exist)")
        label(content: "  [r] - Reset all data")
        label(content: "  [q] - Quit")

        if length(model.ideas) > 0 do
          label(content: "")
          label(content: "Your Ideas:", attributes: [color(:cyan)])

          for {idea, idx} <- Enum.with_index(model.ideas, 1) do
            label(content: "  #{idx}. #{idea}")
          end
        end
      end
    end
  end

  # Input screen - matches ui.zig:291-333
  defp render_input(model) do
    title_text = if length(model.ideas) == 0 do
      "Enter your first idea"
    else
      "Enter another idea"
    end

    view do
      panel title: title_text, height: :fill do
        if length(model.ideas) > 0 do
          label(content: "Current ideas: #{length(model.ideas)}", attributes: [color(:white)])
          label(content: "Your new idea will be compared to all existing ideas", attributes: [color(:white)])
          label(content: "")
        end

        label(content: "> #{model.current_input}_", attributes: [color(:green)])

        if model.error_message do
          label(content: "")
          label(content: model.error_message, attributes: [color(:red)])
        end

        label(content: "")
        label(content: "[Enter] Submit idea  [Esc] Back to menu", attributes: [color(:white)])
      end
    end
  end

  # Analyzing screen - matches ui.zig:336-351
  defp render_analyzing(model) do
    view do
      row do
        column(size: 12) do
          panel(title: "Analyzing", height: :fill) do
            label(content: "")
            label(content: "   Analyzing semantic relationships...", attributes: [color(:yellow)])
            label(content: "   Please wait while the LLM processes your idea.")
            label(content: "")
            # Could add spinner animation here with periodic updates
          end
        end
      end
    end
  end

  # Graph view - matches ui.zig:354-484
  defp render_graph(model) do
    view do
      panel title: "Semantic Relationship Graph", height: :fill do
        # Render vertices (simplified ASCII representation)
        render_vertices(model.graph.vertices)

        label(content: "")
        label(content: "Relationships:", attributes: [color(:cyan)])

        # Render edges with selection
        for {edge, idx} <- Enum.with_index(model.graph.edges) do
          is_selected = model.selected_edge == idx
          attrs = if is_selected, do: [color(:black), background(:white)], else: []

          from = find_vertex(model.graph.vertices, edge.from_vertex_id)
          to = find_vertex(model.graph.vertices, edge.to_vertex_id)
          symbol = relationship_symbol(edge.relation_type)

          label(
            content: "  #{from.content} #{symbol} #{to.content} (#{Float.round(edge.certainty, 2)})",
            attributes: attrs
          )
        end

        label(content: "")
        label(content: "Legend:", attributes: [color(:yellow)])
        label(content: "  → Implicative  ⊆ Hierarchical  ⇒ Causal")
        label(content: "  ⊥ Contradictory  ≡ Synonymous  ≈ Analogous")

        label(content: "")
        label(content: "[↑↓] Select edge  [Esc/h] Back to menu  [q] Quit", attributes: [color(:white)])
      end
    end
  end

  # Helper functions
  defp render_vertices(vertices) do
    # Simple list view (force-directed layout in terminal is complex)
    label(content: "Vertices:", attributes: [color(:cyan)])

    for vertex <- vertices do
      label(content: "  • #{vertex.content}")
    end
  end

  defp relationship_symbol(type) do
    case type do
      :contradictory -> "⊥"
      :implicative -> "→"
      :hierarchical -> "⊆"
      :evolutionary -> "⟿"
      :analogous -> "≈"
      :synonymous -> "≡"
      :antonymous -> "≠"
      :part_whole -> "∈"
      :causal -> "⇒"
    end
  end

  defp validate_and_analyze(content) do
    # Call Ash actions
    with {:ok, _} <- validate_input(content),
         {:ok, result} <- GraphAPI.Graph.analyze_new_idea(%{content: content}) do
      {:ok, result}
    else
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  defp move_selection(nil, :down, graph) when length(graph.edges) > 0, do: 0
  defp move_selection(nil, :up, _graph), do: nil
  defp move_selection(idx, :up, _graph) when idx > 0, do: idx - 1
  defp move_selection(idx, :up, _graph), do: idx
  defp move_selection(idx, :down, graph) when idx < length(graph.edges) - 1, do: idx + 1
  defp move_selection(idx, :down, _graph), do: idx

  defp find_vertex(vertices, id) do
    Enum.find(vertices, fn v -> v.id == id end)
  end

  defp reset_graph do
    GraphAPI.Graph.reset_graph()
  end

  defp validate_input(content) do
    cond do
      String.trim(content) == "" -> {:error, "Input cannot be empty"}
      String.length(content) > 1000 -> {:error, "Input too long (max 1000 characters)"}
      true -> {:ok, content}
    end
  end

  defp format_error(error), do: "Error: #{inspect(error)}"
end
```

#### Running the TUI Application

```elixir
# In your main application module
defmodule SemanticGraph.Application do
  use Application

  def start(_type, _args) do
    children = [
      # Start the Ash API and resources
      {GraphAPI, []},

      # Start the Ratatouille app
      {Ratatouille.Runtime.Supervisor,
        runtime: [app: SemanticGraphTUI, shutdown: {:application, :semantic_graph}]}
    ]

    opts = [strategy: :one_for_one, name: SemanticGraph.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

**Advantages of Ratatouille**:
- ✅ **True terminal interface** - maintains CLI-first experience
- ✅ **Event-driven architecture** - similar to your current event loop
- ✅ **Color and styling** - supports Unicode symbols (⊥, →, ⊆, etc.)
- ✅ **Layout system** - panels, rows, columns like libvaxis
- ✅ **Active development** - well-maintained with good documentation
- ✅ **Pure Elixir** - no FFI or C bindings to manage
- ✅ **Testing support** - can simulate key events in tests

**Considerations**:
- ⚠️ **Graph visualization**: Terminal-based force-directed layout is complex; simplified ASCII representation works well for text-heavy graphs
- ⚠️ **Performance**: Elixir VM adds slight overhead vs. compiled Zig (negligible for I/O-bound LLM calls)
- ✅ **Can always add Phoenix LiveView later** for web-based visualization without removing TUI

#### Alternative: Dual Interface Strategy

You can provide **both** TUI and web interfaces:

```elixir
# CLI mode (default)
$ ./semantic_graph
> Launches Ratatouille TUI

# Web mode
$ ./semantic_graph --web
> Starts Phoenix server on http://localhost:4000

# MCP server mode
$ ./semantic_graph --mcp
> Runs headless MCP JSON-RPC server
```

This gives users flexibility without sacrificing the terminal experience.

---

## 4. Migration Strategy

### 4.1 Phased Approach

#### Phase 1: Core Domain (2 weeks)
1. Set up Phoenix + Ash project
2. Define Vertex, Edge, Graph resources
3. Implement basic CRUD operations
4. Port validation logic

**Deliverable**: Working graph API with Ash resources

#### Phase 2: LLM Integration (1 week)
1. Implement LLM.Client with Tesla
2. Port prompt building logic
3. Implement relationship parsing
4. Add custom Ash action for analysis

**Deliverable**: `analyze_new_idea` action working end-to-end

#### Phase 3: MCP Protocol Server (1.5 weeks)
1. Implement JSON-RPC 2.0 handler
2. Port MCP tools (add_idea, analyze_idea, etc.)
3. Port MCP resources (graph://state, etc.)
4. Add comprehensive tests

**Deliverable**: MCP HTTP server compatible with Claude Desktop

#### Phase 4: Ratatouille TUI Interface (1 week)
1. Set up Ratatouille runtime and supervision
2. Implement UI modes (help, input, analyzing, viewing_graph)
3. Port keyboard event handling
4. Add graph rendering with ASCII/Unicode symbols

**Deliverable**: Terminal UI with feature parity to Zig version

#### Phase 5: Concurrency & Performance (1 week)
1. Optimize ETS usage
2. Implement caching strategy
3. Add Task supervision for LLM calls
4. Load testing and tuning

**Deliverable**: Production-ready performance

### 4.2 Parallel Development

Can develop in parallel:
- ✅ Domain logic (Phase 1) independent of UI
- ✅ LLM client (Phase 2) can be tested standalone
- ✅ MCP server (Phase 3) and Ratatouille TUI (Phase 4) are separate interfaces

### 4.3 Testing Strategy

```elixir
# Test hierarchy
test/
├── graph_api/
│   ├── vertex_test.exs           # Ash resource tests
│   ├── edge_test.exs
│   └── graph_test.exs             # Custom action tests
├── llm/
│   └── client_test.exs            # Mock HTTP responses
├── mcp/
│   ├── protocol_test.exs          # JSON-RPC compliance
│   └── integration_test.exs       # End-to-end MCP flows
├── app_web/
│   └── mcp_controller_test.exs    # HTTP endpoint tests
└── tui/
    └── ratatouille_test.exs       # TUI event simulation tests
```

---

## 5. Risk Assessment

### 5.1 Technical Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **Graph operations don't fit Ash model** | High | Medium | Use custom actions, fallback to GenServer |
| **Performance degradation** | Medium | Low | ETS is fast, profile early |
| **Ratatouille rendering limitations** | Medium | Low | Use simplified ASCII graph representation |
| **MCP protocol incompatibility** | High | Low | Maintain strict JSON-RPC 2.0 compliance |
| **LLM integration complexity** | Medium | Low | Tesla handles most edge cases |
| **Team unfamiliar with Elixir** | High | ? | Training period, pair programming |

### 5.2 Benefits vs. Trade-offs

#### Benefits of Elixir/Ash

✅ **Concurrency**:
- OTP handles thousands of concurrent MCP connections
- No manual mutex management
- Built-in supervision and fault tolerance

✅ **Maintainability**:
- Declarative Ash resources reduce boilerplate
- Pattern matching for cleaner error handling
- Extensive testing support

✅ **Ecosystem**:
- Phoenix for web APIs
- Tesla/Req for HTTP clients
- Ecto for future database persistence
- Rich tooling (Mix, ExUnit, Dialyzer)

✅ **Scalability**:
- Distributed Erlang for multi-node graphs
- Hot code upgrades
- Built-in monitoring (Observer, Telemetry)

#### Trade-offs

✅ **TUI Maintained**:
- Ratatouille provides terminal interface
- Similar feature set to libvaxis
- Simplified graph rendering (ASCII art vs. force-directed layout)

⚠️ **Performance**:
- Erlang VM adds overhead vs. compiled Zig
- For this use case: negligible (I/O bound by LLM calls)
- Ratatouille rendering ~60fps (more than sufficient)

⚠️ **Binary Size**:
- Zig binary: ~500KB-2MB
- Elixir release: ~30-50MB (includes Erlang VM)
- Trade-off: Larger binary for OTP runtime benefits

⚠️ **Startup Time**:
- Zig: <100ms
- Elixir: ~1-2 seconds (VM initialization)
- Acceptable for interactive TUI application

---

## 6. Recommendations

### 6.1 Primary Recommendation: ✅ **PROCEED with Elixir/Ash + Ratatouille**

**Strong recommendation because**:
- ✅ **Maintains terminal UI experience** via Ratatouille
- ✅ Excellent concurrency for MCP HTTP server
- ✅ Cleaner, more maintainable code (declarative Ash resources)
- ✅ Rich Elixir ecosystem (Tesla, Phoenix, Ecto)
- ✅ Built-in OTP supervision and fault tolerance
- ✅ Optional Phoenix LiveView for web interface later

**Architecture**:
```
Elixir Application
├── Ash Resources (Vertex, Edge, Graph)
├── Ratatouille TUI (Terminal Interface) ← Primary UI
├── Phoenix HTTP (MCP Protocol Server)
├── GenServer (Graph Manager)
├── Tesla/Req (LLM Client with retry/timeout)
└── ETS (In-memory storage)

Optional:
└── Phoenix LiveView (Web UI for collaboration)
```

### 6.2 Alternative: ⚠️ **KEEP Zig** if...

**Only consider staying with Zig if**:
- Team has zero Elixir experience and no time to learn
- Performance is paramount (sub-100ms latency requirements)
- Binary size critical (<5MB hard constraint)
- Instant startup time required (<100ms)

Note: For this application, these constraints likely don't apply since:
- I/O bound by LLM API calls (seconds of latency)
- Interactive TUI tolerates 1-2s startup time
- 30-50MB binary size is reasonable for modern systems

### 6.3 Hybrid Approach: ❌ **NOT Recommended**

Given that Ratatouille maintains the TUI experience, a hybrid approach (Zig TUI + Elixir backend) is unnecessary complexity. Choose either full Elixir or full Zig.

---

## 7. Code Comparison Examples

### 7.1 Adding a Vertex

**Zig** (graph.zig:130-149):
```zig
pub fn addVertex(self: *SemanticGraph, content: []const u8, group: usize) !usize {
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
```

**Elixir/Ash**:
```elixir
# Definition
defmodule GraphAPI.Vertex do
  use Ash.Resource, data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key :id
    attribute :content, :string, allow_nil?: false
    attribute :x, :float, default: 0.0
    attribute :y, :float, default: 0.0
    attribute :group, :integer, default: 0
  end

  actions do
    create :add_idea do
      accept [:content, :group]
      validate present(:content)
      validate string_length(:content, max: 1000)
    end
  end
end

# Usage
GraphAPI.Vertex
|> Ash.Changeset.for_create(:add_idea, %{
  content: "Machine learning",
  group: 0
})
|> Ash.create()
```

**Lines of Code**: Zig 19, Elixir ~25 (but includes validation)

### 7.2 Thread-Safe Operations

**Zig** (thread_safe_graph.zig:26-30):
```zig
pub fn addVertex(self: *Self, content: []const u8) ![]const u8 {
    self.mutex.lock();
    defer self.mutex.unlock();
    return try self.graph_data.addVertex(content);
}
```

**Elixir**:
```elixir
defmodule GraphManager do
  use GenServer

  def add_vertex(content) do
    GenServer.call(__MODULE__, {:add_vertex, content})
  end

  def handle_call({:add_vertex, content}, _from, state) do
    {:ok, vertex} = GraphAPI.Vertex
      |> Ash.Changeset.for_create(:add_idea, %{content: content})
      |> Ash.create()

    {:reply, {:ok, vertex}, state}
  end
end
```

**Safety**: Elixir GenServer eliminates manual lock/unlock

---

## 8. Conclusion

### 8.1 Feasibility: ✅ **HIGHLY FEASIBLE**

Porting to Elixir/Ash is **highly recommended** with **no major compromises**:

1. ✅ **Terminal UI maintained** via Ratatouille
2. ✅ **Improved concurrency** with OTP (thousands of MCP connections)
3. ✅ **Cleaner architecture** with Ash resources and GenServer
4. ✅ **Estimated timeline**: 5-7 weeks for feature parity (reduced from 6-8 weeks due to Ratatouille)

**Key Insight**: Discovery of Ratatouille as a viable TUI solution eliminates the primary trade-off that was holding back this port.

### 8.2 When to Choose Elixir/Ash + Ratatouille

✅ **Strongly recommended if**:
- Building a **concurrent system** (MCP HTTP with multiple clients)
- Want **terminal-first experience** with Ratatouille TUI
- Need **fault tolerance** and automatic process supervision
- Plan to add **real-time collaboration** features later
- Prefer **declarative** resource definitions over imperative code
- Want **hot code upgrades** for zero-downtime deployments

⚠️ **Consider staying with Zig only if**:
- Team has **zero Elixir experience** and no time/budget for learning
- **Sub-100ms startup time** is a hard requirement
- **Binary size <5MB** is a hard constraint
- No plans for concurrency or web features ever

**Verdict**: For most use cases, **Elixir/Ash + Ratatouille is superior** to the current Zig implementation.

### 8.3 Next Steps

**Recommended prototyping sequence** (3-4 days total):

1. **Day 1**: Set up Phoenix + Ash project, define Vertex/Edge resources
2. **Day 2**: Implement `analyze_new_idea` custom action with mock LLM
3. **Day 3**: Build Ratatouille TUI with all 4 modes (help, input, analyzing, viewing)
4. **Day 4**: Test end-to-end: TUI → Ash actions → graph updates

**Decision point**: After prototype, evaluate:
- Is Ratatouille TUI comparable to libvaxis for your needs?
- Are Ash resources expressive enough for graph operations?
- Is team comfortable with Elixir/Ash patterns?

If all three are "yes" → **Proceed with full port**

---

## Appendix A: Resource Definitions (Full Example)

```elixir
# lib/graph_api/resources/vertex.ex
defmodule GraphAPI.Resources.Vertex do
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshJsonApi.Resource]

  json_api do
    type "vertex"
  end

  attributes do
    uuid_primary_key :id

    attribute :content, :string do
      allow_nil? false
      constraints max_length: 1000
    end

    attribute :x, :float, default: 0.0
    attribute :y, :float, default: 0.0
    attribute :group, :integer, default: 0

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :outgoing_edges, GraphAPI.Resources.Edge,
      destination_attribute: :from_vertex_id

    has_many :incoming_edges, GraphAPI.Resources.Edge,
      destination_attribute: :to_vertex_id
  end

  actions do
    defaults [:read, :destroy]

    create :add_idea do
      accept [:content, :group]

      validate present(:content)
      validate string_length(:content, max: 1000, min: 1)

      change fn changeset, _context ->
        # Sanitize content (trim whitespace)
        content = Ash.Changeset.get_attribute(changeset, :content)
        sanitized = String.trim(content)
        Ash.Changeset.force_change_attribute(changeset, :content, sanitized)
      end
    end

    update :update_position do
      accept [:x, :y]
    end
  end

  code_interface do
    define_for GraphAPI
    define :add_idea, action: :add_idea
    define :update_position, action: :update_position
    define :get_by_id, action: :read, get_by: [:id]
    define :list_all, action: :read
  end

  validations do
    validate numeral_in_range(:group, 0..1)
  end
end

# lib/graph_api/resources/edge.ex
defmodule GraphAPI.Resources.Edge do
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key :id

    attribute :relation_type, :atom do
      constraints one_of: [
        :contradictory, :implicative, :hierarchical,
        :evolutionary, :analogous, :synonymous,
        :antonymous, :part_whole, :causal
      ]
    end

    attribute :certainty, :float do
      constraints min: 0.0, max: 1.0
    end

    attribute :description, :string

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :from_vertex, GraphAPI.Resources.Vertex do
      attribute_writable? true
    end

    belongs_to :to_vertex, GraphAPI.Resources.Vertex do
      attribute_writable? true
    end
  end

  actions do
    defaults [:read, :destroy]

    create :add_relationship do
      accept [:from_vertex_id, :to_vertex_id, :relation_type, :certainty, :description]

      # Check for duplicate and update if new certainty is higher
      change fn changeset, context ->
        from_id = Ash.Changeset.get_attribute(changeset, :from_vertex_id)
        to_id = Ash.Changeset.get_attribute(changeset, :to_vertex_id)
        rel_type = Ash.Changeset.get_attribute(changeset, :relation_type)
        new_certainty = Ash.Changeset.get_attribute(changeset, :certainty)

        existing = GraphAPI.Resources.Edge
          |> Ash.Query.filter(
            from_vertex_id == ^from_id and
            to_vertex_id == ^to_id and
            relation_type == ^rel_type
          )
          |> Ash.read_one(context: context)

        case existing do
          {:ok, nil} ->
            # No duplicate, proceed with create
            changeset

          {:ok, edge} when edge.certainty < new_certainty ->
            # Update existing with higher certainty
            Ash.Changeset.for_update(edge, :update_certainty, %{
              certainty: new_certainty,
              description: Ash.Changeset.get_attribute(changeset, :description)
            })

          {:ok, _edge} ->
            # Duplicate with equal or higher certainty, skip
            Ash.Changeset.add_error(changeset, "Duplicate edge with equal or higher certainty")
        end
      end
    end

    update :update_certainty do
      accept [:certainty, :description]
    end
  end

  code_interface do
    define_for GraphAPI
    define :add_relationship, action: :add_relationship
  end
end

# lib/graph_api/api.ex
defmodule GraphAPI do
  use Ash.Api

  resources do
    resource GraphAPI.Resources.Vertex
    resource GraphAPI.Resources.Edge
  end
end
```

---

## Appendix B: Force-Directed Layout in Elixir

```elixir
defmodule GraphAPI.Layout.ForceDirected do
  @moduledoc """
  Port of force-directed graph layout algorithm from graph.zig:226-287
  """

  def calculate_layout(vertices, edges, width, height) do
    return vertices if Enum.empty?(vertices)

    # Initial positioning - split into groups
    vertices = initialize_positions(vertices, width, height)

    # Force-directed adjustment
    iterations = 50
    k = :math.sqrt(width * height / length(vertices))
    t = k / 10.0

    Enum.reduce(1..iterations, vertices, fn _i, verts ->
      apply_forces(verts, k, t, width, height)
    end)
  end

  defp initialize_positions(vertices, width, height) do
    {group0, group1} = Enum.split_with(vertices, & &1.group == 0)

    group0_positioned = position_group(group0, width * 0.25, height, 0)
    group1_positioned = position_group(group1, width * 0.75, height, 0)

    group0_positioned ++ group1_positioned
  end

  defp position_group(vertices, x, height, start_idx) do
    count = length(vertices)

    vertices
    |> Enum.with_index(start_idx)
    |> Enum.map(fn {vertex, idx} ->
      y = height * (idx + 1.0) / (count + 1.0)
      %{vertex | x: x, y: y}
    end)
  end

  defp apply_forces(vertices, k, t, width, height) do
    Enum.map(vertices, fn v1 ->
      # Calculate repulsive forces
      {fx, fy} = Enum.reduce(vertices, {0.0, 0.0}, fn v2, {acc_fx, acc_fy} ->
        if v1.id == v2.id do
          {acc_fx, acc_fy}
        else
          dx = v1.x - v2.x
          dy = v1.y - v2.y
          dist = :math.sqrt(dx * dx + dy * dy) + 0.01

          repulsion = k * k / dist
          {
            acc_fx + (dx / dist) * repulsion,
            acc_fy + (dy / dist) * repulsion
          }
        end
      end)

      # Constrain to group side
      target_x = if v1.group == 0, do: width * 0.25, else: width * 0.75
      fx = fx + (target_x - v1.x) * 0.1

      # Update position
      new_x = v1.x + fx * t * 0.01
      new_y = v1.y + fy * t * 0.01

      # Keep within bounds
      new_x = max(10.0, min(width - 10.0, new_x))
      new_y = max(5.0, min(height - 5.0, new_y))

      %{v1 | x: new_x, y: new_y}
    end)
  end
end
```

---

**End of Feasibility Study**
