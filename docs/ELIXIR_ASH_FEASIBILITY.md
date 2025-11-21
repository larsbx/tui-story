# Feasibility Study: Porting Semantic Graph TUI to Elixir/Ash Framework

**Date**: 2025-11-21
**Current Stack**: Zig + libvaxis
**Target Stack**: Elixir + Ash Framework
**Prepared by**: Architecture Analysis

---

## Executive Summary

**Recommendation**: ✅ **FEASIBLE with Strategic Modifications**

Porting this Zig-based semantic graph application to Elixir with Ash is technically feasible but requires significant architectural changes. Elixir/Ash excels at concurrent web APIs but the TUI component and graph-specific operations need alternative approaches.

**Key Findings**:
- **High Compatibility**: MCP HTTP server, LLM integration, concurrent access patterns
- **Medium Compatibility**: Graph data modeling, relationship analysis workflows
- **Low Compatibility**: TUI interface (requires different tooling)
- **Estimated Effort**: 6-8 weeks (single developer)

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

### 3.5 TUI Interface: Critical Decision Point

#### ❌ libvaxis (Zig) → No Direct Equivalent in Elixir

**Current**: Terminal UI with vaxis library
**Problem**: Elixir has minimal TUI support

**Options**:

##### Option A: Phoenix LiveView (Web-based TUI)
```elixir
defmodule AppWeb.GraphLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, assign(socket,
      ideas: load_ideas(),
      graph_svg: generate_graph_svg(),
      input: "",
      mode: :help
    )}
  end

  def handle_event("add_idea", %{"content" => content}, socket) do
    # Add idea via Ash action
    {:ok, result} = GraphAPI.Graph.analyze_new_idea(%{content: content})

    # Update UI reactively
    {:noreply, assign(socket,
      ideas: load_ideas(),
      graph_svg: generate_graph_svg()
    )}
  end
end
```

**Pros**:
- ✅ Real-time updates (WebSocket)
- ✅ Rich visualization (D3.js for graph layout)
- ✅ Accessible from any browser
- ✅ Multi-user support

**Cons**:
- ❌ Not a true terminal app
- ❌ Requires browser
- ❌ Different UX paradigm

##### Option B: Ratatouille (Elixir TUI Library)
```elixir
defmodule GraphTUI do
  use Ratatouille.App

  def init(_context) do
    %{ideas: [], mode: :help, input: ""}
  end

  def update(model, msg) do
    case msg do
      {:event, %{key: key}} when key == ?e ->
        %{model | mode: :input}

      {:event, %{key: key}} when key == ?\r and model.mode == :input ->
        # Call Ash action
        GraphAPI.Graph.analyze_new_idea(%{content: model.input})
        %{model | mode: :viewing, input: ""}

      _ ->
        model
    end
  end

  def render(model) do
    view do
      panel title: "Semantic Graph" do
        label(content: "Ideas: #{length(model.ideas)}")
        # ... render graph
      end
    end
  end
end
```

**Pros**:
- ✅ True terminal interface
- ✅ Similar to current UX

**Cons**:
- ⚠️ Ratatouille is less mature than libvaxis
- ⚠️ Limited layout capabilities
- ❌ No good force-directed graph rendering in terminal

##### Option C: Keep Zig TUI + Elixir Backend (Hybrid)

Use Zig TUI as a client, Elixir as backend via HTTP MCP.

**Pros**:
- ✅ Best of both worlds
- ✅ Reuse existing TUI code

**Cons**:
- ❌ Maintains two codebases
- ❌ Defeats purpose of full port

**Recommendation**: **Use Phoenix LiveView** for modern web interface with better visualization capabilities.

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

#### Phase 4: LiveView Interface (1.5 weeks)
1. Design LiveView UI mockups
2. Implement graph visualization with D3.js
3. Port input handling and modes
4. Add real-time updates

**Deliverable**: Web-based graph interface

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
- ✅ MCP server (Phase 3) and LiveView (Phase 4) are separate interfaces

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
└── app_web/
    ├── mcp_controller_test.exs    # HTTP endpoint tests
    └── graph_live_test.exs        # LiveView integration tests
```

---

## 5. Risk Assessment

### 5.1 Technical Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **Graph operations don't fit Ash model** | High | Medium | Use custom actions, fallback to GenServer |
| **Performance degradation** | Medium | Low | ETS is fast, profile early |
| **TUI experience loss** | High | High | Accept trade-off, use LiveView |
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

❌ **TUI Loss**:
- No equivalent to libvaxis in Elixir
- Must accept web-based interface

⚠️ **Performance**:
- Erlang VM adds overhead vs. compiled Zig
- For this use case: negligible (I/O bound by LLM calls)

⚠️ **Binary Size**:
- Zig binary: ~500KB-2MB
- Elixir release: ~30-50MB (includes Erlang VM)

⚠️ **Startup Time**:
- Zig: <100ms
- Elixir: ~1-2 seconds (VM initialization)

---

## 6. Recommendations

### 6.1 Primary Recommendation: ✅ **PROCEED with Elixir/Ash**

**If your goals include**:
- Scaling to many concurrent users
- Web-based interface acceptable
- Future database persistence
- Rich API ecosystem
- Fault-tolerant system

**Architecture**:
```
Elixir/Phoenix Application
├── Ash Resources (Vertex, Edge, Graph)
├── Phoenix LiveView (Web UI)
├── Phoenix HTTP (MCP Protocol)
├── GenServer (Graph Manager)
├── Tesla/Req (LLM Client)
└── ETS (In-memory storage)
```

### 6.2 Alternative: ❌ **KEEP Zig** if...

- Terminal UI is critical requirement
- Single-user CLI tool is the primary use case
- Performance is paramount (sub-millisecond latency)
- No need for web APIs or concurrency

### 6.3 Hybrid Approach: ⚠️ **Consider for transition**

1. Port backend to Elixir/Ash (MCP server only)
2. Keep Zig TUI as MCP client
3. Gradually introduce LiveView as optional interface
4. Deprecate Zig TUI over time

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

### 8.1 Feasibility: ✅ **YES**

Porting to Elixir/Ash is **technically feasible** with the following caveats:

1. **Accept web-based UI** instead of TUI
2. **Use custom Ash actions** for complex graph operations
3. **Invest in learning** Ash framework patterns
4. **Estimated timeline**: 6-8 weeks for feature parity

### 8.2 When to Choose Elixir/Ash

✅ **Choose if**:
- Building a **web service** (MCP HTTP primary interface)
- Need **high concurrency** (many simultaneous users)
- Want **fault tolerance** and supervision
- Plan to add **real-time collaboration**
- Prefer **declarative** resource definitions

❌ **Avoid if**:
- **TUI is non-negotiable**
- **Single-user CLI** is the primary use case
- Team has **no Elixir experience** and no time to learn
- **Binary size** or **startup time** are critical

### 8.3 Next Steps

1. **Prototype** core graph operations in Ash (1 day)
2. **Test** custom action for `analyze_new_idea` (2 days)
3. **Evaluate** LiveView for graph visualization (2 days)
4. **Decision point**: Proceed with full port or stay with Zig

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
