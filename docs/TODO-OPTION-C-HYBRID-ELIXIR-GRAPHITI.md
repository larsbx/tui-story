# TODO: Option C - Hybrid Elixir/Ash + Graphiti + Ratatouille TUI

**Created:** 2025-11-22
**Architecture:** Hybrid approach combining Elixir/Ash backend, Graphiti knowledge graph, and Ratatouille TUI
**Based on:**
- [ADR-006: Graphiti Knowledge Graph Integration](./architecture/ADR-006-graphiti-knowledge-graph-integration.md)
- [Elixir/Ash Feasibility Study](./ELIXIR_ASH_FEASIBILITY.md)

---

## Executive Summary

**Option C** represents a hybrid architecture that maximizes the strengths of each technology:
- **Elixir/Ash**: Declarative resources, OTP concurrency, fault tolerance
- **Graphiti**: Temporal knowledge graphs, LLM-powered entity extraction, episodic memory
- **Ratatouille**: Terminal-first UI maintaining current UX
- **Neo4j/FalkorDB**: Production-grade graph database backend

**Estimated Timeline:** 7-9 weeks (single developer)
**Risk Level:** Medium (new stack but well-documented)
**Key Benefit:** Best-in-class concurrency + temporal knowledge graphs + maintained TUI experience

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│         Elixir Application (Phoenix + Ash)              │
│                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │ Ratatouille  │  │ Phoenix HTTP │  │ MCP Handler  │ │
│  │ TUI (Primary)│  │ (Optional)   │  │ (JSON-RPC)   │ │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘ │
│         │                 │                 │          │
│         └─────────────────┼─────────────────┘          │
│                           │                            │
│         ┌─────────────────▼──────────────────┐         │
│         │      Ash API Layer                 │         │
│         │  • GraphAPI.Vertex (Resource)      │         │
│         │  • GraphAPI.Edge (Resource)        │         │
│         │  • GraphAPI.Graph (Custom Actions) │         │
│         └────────────┬────────────────────────┘        │
│                      │                                 │
│         ┌────────────┴────────────────┐                │
│         │                             │                │
│    ┌────▼─────────┐        ┌─────────▼──────────┐     │
│    │ GraphManager │        │ GraphitiIntegration│     │
│    │  (GenServer) │        │    (GenServer)     │     │
│    │ - ETS cache  │        │ - HTTP client      │     │
│    │ - Layout calc│        │ - Fallback logic   │     │
│    └──────────────┘        └──────┬─────────────┘     │
│                                   │                    │
└───────────────────────────────────┼────────────────────┘
                                    │ HTTP/JSON
                          ┌─────────▼──────────┐
                          │ Graphiti Service   │
                          │   (FastAPI/Python) │
                          │ - Entity extraction│
                          │ - Temporal queries │
                          │ - Graph reasoning  │
                          └─────────┬──────────┘
                                    │ Bolt Protocol
                             ┌──────▼────────┐
                             │ Neo4j/FalkorDB│
                             │  Graph Database│
                             └───────────────┘
```

---

## Phase 1: Foundation Setup (Week 1)

### 1.1 Elixir/Phoenix Project Setup

**Priority:** CRITICAL
**Effort:** 4 hours
**Dependencies:** None

**Tasks:**
- [ ] Create new Phoenix project: `mix phx.new semantic_graph --no-ecto --no-html --no-webpack`
- [ ] Add Ash dependencies to `mix.exs`:
  - `{:ash, "~> 3.0"}`
  - `{:ash_json_api, "~> 1.0"}`
  - `{:ratatouille, "~> 0.5.0"}`
  - `{:tesla, "~> 1.8"}`
  - `{:jason, "~> 1.4"}`
- [ ] Configure application supervision tree in `lib/semantic_graph/application.ex`
- [ ] Set up development environment variables
- [ ] Verify `mix compile` succeeds

**Deliverable:** Clean Phoenix + Ash project structure

**Validation:**
```bash
mix deps.get
mix compile
mix test  # Should pass (no tests yet)
```

---

### 1.2 Graphiti Service Setup (Python)

**Priority:** CRITICAL
**Effort:** 6 hours
**Dependencies:** 1.1

**Tasks:**
- [ ] Create `graphiti_service/` directory at project root
- [ ] Set up Python virtual environment: `python -m venv venv`
- [ ] Install dependencies:
  - `pip install fastapi uvicorn graphiti-core neo4j`
- [ ] Create basic FastAPI app structure:
  ```
  graphiti_service/
  ├── main.py              # FastAPI app entry point
  ├── models.py            # Pydantic models
  ├── graphiti_client.py   # Graphiti wrapper
  ├── config.py            # Environment config
  └── requirements.txt     # Dependencies
  ```
- [ ] Implement health check endpoint: `GET /health`
- [ ] Configure Neo4j connection (local or Docker)
- [ ] Test service startup: `uvicorn main:app --reload`

**Implementation Guide:**
```python
# graphiti_service/main.py
from fastapi import FastAPI, HTTPException
from graphiti_core import Graphiti
from pydantic import BaseModel
from typing import List, Optional
import os

app = FastAPI(title="Graphiti Knowledge Graph Service")

# Initialize Graphiti client
graphiti = Graphiti(
    neo4j_uri=os.getenv("NEO4J_URI", "bolt://localhost:7687"),
    neo4j_user=os.getenv("NEO4J_USER", "neo4j"),
    neo4j_password=os.getenv("NEO4J_PASSWORD", "password")
)

class Episode(BaseModel):
    content: str
    source: Optional[str] = "semantic-graph-tui"
    timestamp: Optional[str] = None

class SearchQuery(BaseModel):
    query: str
    limit: int = 10

@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "graphiti"}

@app.post("/episodes")
async def add_episode(episode: Episode):
    try:
        await graphiti.add_episode(
            episode.content,
            source=episode.source,
            timestamp=episode.timestamp
        )
        return {"status": "ok", "message": "Episode added"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/search")
async def search(query: str, limit: int = 10):
    try:
        results = await graphiti.search(query, limit=limit)
        return results
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
```

**Deliverable:** Running Graphiti FastAPI service

**Validation:**
```bash
# Terminal 1: Start Neo4j
docker run -p 7687:7687 -p 7474:7474 -e NEO4J_AUTH=neo4j/password neo4j:latest

# Terminal 2: Start Graphiti service
cd graphiti_service
source venv/bin/activate
uvicorn main:app --reload

# Terminal 3: Test health check
curl http://localhost:8000/health
# Should return: {"status":"healthy","service":"graphiti"}
```

---

### 1.3 Docker Compose Setup

**Priority:** HIGH
**Effort:** 2 hours
**Dependencies:** 1.1, 1.2

**Tasks:**
- [ ] Create `docker-compose.yml` in project root
- [ ] Define services: Neo4j, Graphiti (FastAPI)
- [ ] Configure networking between services
- [ ] Add volume mounts for Neo4j persistence
- [ ] Create `.env.example` with required variables

**Implementation:**
```yaml
# docker-compose.yml
version: '3.8'

services:
  neo4j:
    image: neo4j:5.14-community
    container_name: semantic_graph_neo4j
    ports:
      - "7474:7474"  # Browser UI
      - "7687:7687"  # Bolt protocol
    environment:
      NEO4J_AUTH: neo4j/password
      NEO4J_PLUGINS: '["apoc"]'
    volumes:
      - neo4j_data:/data
      - neo4j_logs:/logs
    healthcheck:
      test: ["CMD", "wget", "--spider", "http://localhost:7474"]
      interval: 10s
      timeout: 5s
      retries: 5

  graphiti:
    build: ./graphiti_service
    container_name: semantic_graph_graphiti
    ports:
      - "8000:8000"
    environment:
      NEO4J_URI: bolt://neo4j:7687
      NEO4J_USER: neo4j
      NEO4J_PASSWORD: password
      ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY}
    depends_on:
      neo4j:
        condition: service_healthy
    volumes:
      - ./graphiti_service:/app
    command: uvicorn main:app --host 0.0.0.0 --port 8000 --reload

volumes:
  neo4j_data:
  neo4j_logs:
```

**Deliverable:** One-command environment startup

**Validation:**
```bash
docker-compose up -d
curl http://localhost:8000/health
docker-compose logs -f graphiti
docker-compose down
```

---

## Phase 2: Core Domain (Ash Resources) (Week 2)

### 2.1 Define Vertex Resource

**Priority:** CRITICAL
**Effort:** 4 hours
**Dependencies:** 1.1

**Tasks:**
- [ ] Create `lib/semantic_graph/resources/vertex.ex`
- [ ] Define Ash resource with ETS data layer
- [ ] Add attributes: id, content, x, y, group
- [ ] Implement `:add_idea` action with validation
- [ ] Add relationships (outgoing_edges, incoming_edges)
- [ ] Define code interface for easy API calls
- [ ] Write unit tests in `test/semantic_graph/resources/vertex_test.exs`

**Implementation:**
```elixir
# lib/semantic_graph/resources/vertex.ex
defmodule SemanticGraph.Resources.Vertex do
  use Ash.Resource,
    domain: SemanticGraph.GraphAPI,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshJsonApi.Resource]

  json_api do
    type "vertex"
  end

  attributes do
    uuid_primary_key :id

    attribute :content, :string do
      allow_nil? false
      constraints max_length: 1000, min_length: 1
    end

    attribute :x, :float, default: 0.0
    attribute :y, :float, default: 0.0
    attribute :group, :integer, default: 0

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :outgoing_edges, SemanticGraph.Resources.Edge,
      destination_attribute: :from_vertex_id

    has_many :incoming_edges, SemanticGraph.Resources.Edge,
      destination_attribute: :to_vertex_id
  end

  actions do
    defaults [:read, :destroy]

    create :add_idea do
      accept [:content, :group]

      validate present(:content)
      validate string_length(:content, max: 1000, min: 1)

      # Sanitize and trim content
      change fn changeset, _context ->
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
    define :add_idea, action: :add_idea
    define :update_position, action: :update_position
    define :get_by_id, action: :read, get_by: [:id]
    define :list_all, action: :read
  end

  validations do
    validate numeral_in_range(:group, 0..1)
  end
end
```

**Test Coverage:**
```elixir
# test/semantic_graph/resources/vertex_test.exs
defmodule SemanticGraph.Resources.VertexTest do
  use ExUnit.Case
  alias SemanticGraph.Resources.Vertex

  test "creates vertex with valid content" do
    {:ok, vertex} = Vertex.add_idea(%{content: "Machine learning"})
    assert vertex.content == "Machine learning"
    assert vertex.group == 0
    assert is_float(vertex.x)
  end

  test "rejects empty content" do
    assert {:error, _} = Vertex.add_idea(%{content: ""})
  end

  test "rejects content over 1000 characters" do
    long_content = String.duplicate("a", 1001)
    assert {:error, _} = Vertex.add_idea(%{content: long_content})
  end

  test "trims whitespace from content" do
    {:ok, vertex} = Vertex.add_idea(%{content: "  Test  "})
    assert vertex.content == "Test"
  end
end
```

**Deliverable:** Working Vertex resource with tests

---

### 2.2 Define Edge Resource

**Priority:** CRITICAL
**Effort:** 6 hours
**Dependencies:** 2.1

**Tasks:**
- [ ] Create `lib/semantic_graph/resources/edge.ex`
- [ ] Define relationship types enum (9 types from Zig version)
- [ ] Add attributes: relation_type, certainty, description
- [ ] Implement belongs_to relationships (from_vertex, to_vertex)
- [ ] Add `:add_relationship` action with duplicate handling
- [ ] Implement certainty-based update logic (port from Zig)
- [ ] Write comprehensive tests

**Implementation:**
```elixir
# lib/semantic_graph/resources/edge.ex
defmodule SemanticGraph.Resources.Edge do
  use Ash.Resource,
    domain: SemanticGraph.GraphAPI,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key :id

    attribute :relation_type, :atom do
      constraints one_of: [
        :contradictory,   # ⊥
        :implicative,     # →
        :hierarchical,    # ⊆
        :evolutionary,    # ⟿
        :analogous,       # ≈
        :synonymous,      # ≡
        :antonymous,      # ≠
        :part_whole,      # ∈
        :causal           # ⇒
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
    belongs_to :from_vertex, SemanticGraph.Resources.Vertex do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :to_vertex, SemanticGraph.Resources.Vertex do
      allow_nil? false
      attribute_writable? true
    end
  end

  actions do
    defaults [:read, :destroy]

    create :add_relationship do
      accept [:from_vertex_id, :to_vertex_id, :relation_type, :certainty, :description]

      validate present([:from_vertex_id, :to_vertex_id, :relation_type])

      # Port logic from graph.zig:151-162 - update if higher certainty
      change fn changeset, context ->
        from_id = Ash.Changeset.get_attribute(changeset, :from_vertex_id)
        to_id = Ash.Changeset.get_attribute(changeset, :to_vertex_id)
        rel_type = Ash.Changeset.get_attribute(changeset, :relation_type)
        new_certainty = Ash.Changeset.get_attribute(changeset, :certainty)

        # Check for existing edge
        existing =
          __MODULE__
          |> Ash.Query.filter(
            from_vertex_id == ^from_id and
            to_vertex_id == ^to_id and
            relation_type == ^rel_type
          )
          |> Ash.read_one(authorize?: false)

        case existing do
          {:ok, nil} ->
            # No duplicate, proceed with create
            changeset

          {:ok, edge} when edge.certainty < new_certainty ->
            # Update existing edge with higher certainty
            {:ok, updated} = Ash.Changeset.for_update(edge, :update_certainty, %{
              certainty: new_certainty,
              description: Ash.Changeset.get_attribute(changeset, :description)
            })
            |> Ash.update()

            # Return success without creating new edge
            Ash.Changeset.add_error(changeset,
              field: :from_vertex_id,
              message: "Updated existing edge with higher certainty"
            )

          {:ok, _edge} ->
            # Duplicate with equal/higher certainty, skip
            Ash.Changeset.add_error(changeset,
              field: :from_vertex_id,
              message: "Edge already exists with equal or higher certainty"
            )
        end
      end
    end

    update :update_certainty do
      accept [:certainty, :description]
    end
  end

  code_interface do
    define :add_relationship, action: :add_relationship
    define :list_all, action: :read
  end
end
```

**Deliverable:** Edge resource with deduplication logic

---

### 2.3 Create GraphAPI Domain

**Priority:** CRITICAL
**Effort:** 2 hours
**Dependencies:** 2.1, 2.2

**Tasks:**
- [ ] Create `lib/semantic_graph/graph_api.ex`
- [ ] Define Ash domain (API) module
- [ ] Register Vertex and Edge resources
- [ ] Configure domain-level options
- [ ] Add domain tests

**Implementation:**
```elixir
# lib/semantic_graph/graph_api.ex
defmodule SemanticGraph.GraphAPI do
  use Ash.Domain

  resources do
    resource SemanticGraph.Resources.Vertex
    resource SemanticGraph.Resources.Edge
  end
end
```

**Deliverable:** Unified API for all resources

---

## Phase 3: Graphiti Integration (Week 3)

### 3.1 Elixir HTTP Client for Graphiti

**Priority:** HIGH
**Effort:** 8 hours
**Dependencies:** 1.2, 2.3

**Tasks:**
- [ ] Create `lib/semantic_graph/graphiti/client.ex`
- [ ] Implement Tesla HTTP client with middleware
- [ ] Add retry logic with exponential backoff
- [ ] Implement health check with circuit breaker pattern
- [ ] Add timeout and error handling
- [ ] Create request/response structs
- [ ] Write unit tests with mocked HTTP

**Implementation:**
```elixir
# lib/semantic_graph/graphiti/client.ex
defmodule SemanticGraph.Graphiti.Client do
  @moduledoc """
  HTTP client for Graphiti knowledge graph service.
  Implements circuit breaker and retry logic.
  """

  use Tesla

  plug Tesla.Middleware.BaseUrl, base_url()
  plug Tesla.Middleware.JSON
  plug Tesla.Middleware.Headers, [{"content-type", "application/json"}]

  plug Tesla.Middleware.Retry,
    delay: 1000,
    max_retries: 3,
    max_delay: 8_000,
    should_retry: fn
      {:ok, %{status: status}} when status in 500..599 -> true
      {:ok, _} -> false
      {:error, _} -> true
    end

  plug Tesla.Middleware.Timeout, timeout: 30_000

  defmodule Episode do
    @type t :: %__MODULE__{
      content: String.t(),
      source: String.t() | nil,
      timestamp: String.t() | nil
    }
    defstruct [:content, :source, :timestamp]
  end

  defmodule SearchResult do
    @type t :: %__MODULE__{
      entities: list(map()),
      edges: list(map())
    }
    defstruct entities: [], edges: []
  end

  @doc """
  Check if Graphiti service is healthy and available.
  """
  @spec health_check() :: {:ok, boolean()} | {:error, term()}
  def health_check do
    case get("/health") do
      {:ok, %{status: 200}} -> {:ok, true}
      {:ok, %{status: _}} -> {:ok, false}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Add an episode (concept) to the knowledge graph.
  """
  @spec add_episode(Episode.t()) :: {:ok, map()} | {:error, term()}
  def add_episode(%Episode{} = episode) do
    body = %{
      content: episode.content,
      source: episode.source || "semantic-graph-tui",
      timestamp: episode.timestamp
    }

    case post("/episodes", body) do
      {:ok, %{status: 200, body: response}} ->
        {:ok, response}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Search the knowledge graph for relationships.
  """
  @spec search(String.t(), non_neg_integer()) ::
    {:ok, SearchResult.t()} | {:error, term()}
  def search(query, limit \\ 10) do
    case get("/search", query: [query: query, limit: limit]) do
      {:ok, %{status: 200, body: body}} ->
        result = %SearchResult{
          entities: body["entities"] || [],
          edges: body["edges"] || []
        }
        {:ok, result}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp base_url do
    System.get_env("GRAPHITI_BASE_URL", "http://localhost:8000")
  end
end
```

**Test Coverage:**
```elixir
# test/semantic_graph/graphiti/client_test.exs
defmodule SemanticGraph.Graphiti.ClientTest do
  use ExUnit.Case
  import Tesla.Mock
  alias SemanticGraph.Graphiti.Client

  setup do
    mock fn
      %{method: :get, url: "http://localhost:8000/health"} ->
        json(%{"status" => "healthy"}, status: 200)

      %{method: :post, url: "http://localhost:8000/episodes"} ->
        json(%{"status" => "ok", "message" => "Episode added"}, status: 200)

      %{method: :get, url: "http://localhost:8000/search"} ->
        json(%{
          "entities" => [%{"name" => "ML", "type" => "concept"}],
          "edges" => []
        }, status: 200)
    end

    :ok
  end

  test "health_check returns true when service is healthy" do
    assert {:ok, true} = Client.health_check()
  end

  test "add_episode sends content to Graphiti" do
    episode = %Client.Episode{content: "Machine learning"}
    assert {:ok, _} = Client.add_episode(episode)
  end

  test "search returns results" do
    assert {:ok, %Client.SearchResult{entities: entities}} =
      Client.search("machine learning")
    assert length(entities) > 0
  end
end
```

**Deliverable:** Robust Graphiti HTTP client

---

### 3.2 Graphiti Integration GenServer

**Priority:** HIGH
**Effort:** 6 hours
**Dependencies:** 3.1

**Tasks:**
- [ ] Create `lib/semantic_graph/graphiti/integration.ex`
- [ ] Implement GenServer for managing Graphiti connection state
- [ ] Add fallback mode when Graphiti unavailable
- [ ] Implement sync operations (add concept, search)
- [ ] Add supervision and restart strategy
- [ ] Write integration tests

**Implementation:**
```elixir
# lib/semantic_graph/graphiti/integration.ex
defmodule SemanticGraph.Graphiti.Integration do
  @moduledoc """
  GenServer managing Graphiti integration with graceful fallback.
  Maintains connection state and provides sync operations.
  """

  use GenServer
  require Logger
  alias SemanticGraph.Graphiti.Client

  defmodule State do
    defstruct enabled: false,
              last_health_check: nil,
              health_check_interval: 60_000  # 1 minute
  end

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Check if Graphiti integration is currently enabled.
  """
  def enabled? do
    GenServer.call(__MODULE__, :enabled?)
  end

  @doc """
  Sync a concept to Graphiti knowledge graph.
  Returns :ok even if Graphiti is unavailable (graceful degradation).
  """
  def sync_concept(content) do
    GenServer.call(__MODULE__, {:sync_concept, content}, 35_000)
  end

  @doc """
  Enhance relationships using Graphiti's graph reasoning.
  Returns empty list if Graphiti unavailable.
  """
  def enhance_relationships(concept, existing_concepts) do
    GenServer.call(__MODULE__,
      {:enhance_relationships, concept, existing_concepts},
      35_000
    )
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Perform initial health check
    enabled = check_health()

    if enabled do
      Logger.info("[Graphiti] Integration enabled - service healthy")
    else
      Logger.warn("[Graphiti] Integration disabled - service unavailable, using fallback mode")
    end

    # Schedule periodic health checks
    schedule_health_check()

    {:ok, %State{
      enabled: enabled,
      last_health_check: System.monotonic_time(:second)
    }}
  end

  @impl true
  def handle_call(:enabled?, _from, state) do
    {:reply, state.enabled, state}
  end

  @impl true
  def handle_call({:sync_concept, content}, _from, state) do
    if state.enabled do
      episode = %Client.Episode{
        content: content,
        source: "semantic-graph-tui"
      }

      case Client.add_episode(episode) do
        {:ok, _} ->
          Logger.debug("[Graphiti] Synced concept: #{String.slice(content, 0..50)}")
          {:reply, :ok, state}

        {:error, reason} ->
          Logger.error("[Graphiti] Failed to sync concept: #{inspect(reason)}")
          {:reply, {:error, reason}, state}
      end
    else
      # Graceful degradation - don't fail if Graphiti unavailable
      {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call({:enhance_relationships, concept, _existing}, _from, state) do
    if state.enabled do
      case Client.search(concept, 10) do
        {:ok, results} ->
          # Convert Graphiti edges to our relationship format
          relationships = convert_graphiti_edges(results.edges)
          {:reply, {:ok, relationships}, state}

        {:error, reason} ->
          Logger.error("[Graphiti] Search failed: #{inspect(reason)}")
          {:reply, {:ok, []}, state}
      end
    else
      # Return empty list if disabled
      {:reply, {:ok, []}, state}
    end
  end

  @impl true
  def handle_info(:health_check, state) do
    enabled = check_health()

    if enabled != state.enabled do
      if enabled do
        Logger.info("[Graphiti] Service restored - enabling integration")
      else
        Logger.warn("[Graphiti] Service down - disabling integration")
      end
    end

    schedule_health_check()
    {:noreply, %{state | enabled: enabled, last_health_check: System.monotonic_time(:second)}}
  end

  # Private Helpers

  defp check_health do
    case Client.health_check() do
      {:ok, true} -> true
      _ -> false
    end
  end

  defp schedule_health_check do
    Process.send_after(self(), :health_check, 60_000)
  end

  defp convert_graphiti_edges(graphiti_edges) do
    # TODO: Map Graphiti edge format to SemanticGraph.Resources.Edge format
    # This will require mapping Graphiti's relationship types to our 9 types
    []
  end
end
```

**Deliverable:** Resilient Graphiti integration with fallback

---

### 3.3 Update Application Supervision Tree

**Priority:** HIGH
**Effort:** 2 hours
**Dependencies:** 3.2

**Tasks:**
- [ ] Update `lib/semantic_graph/application.ex`
- [ ] Add Graphiti.Integration to supervision tree
- [ ] Configure restart strategy (permanent, transient, or temporary)
- [ ] Ensure proper startup order
- [ ] Test application startup/shutdown

**Implementation:**
```elixir
# lib/semantic_graph/application.ex
defmodule SemanticGraph.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ash domain
      SemanticGraph.GraphAPI,

      # Start Graphiti integration (optional, graceful degradation)
      {SemanticGraph.Graphiti.Integration, []},

      # Start Phoenix endpoint (if web interface enabled)
      # SemanticGraphWeb.Endpoint,

      # Start Ratatouille TUI (will add in Phase 4)
      # {Ratatouille.Runtime.Supervisor,
      #   runtime: [app: SemanticGraph.TUI, shutdown: {:application, :semantic_graph}]}
    ]

    opts = [strategy: :one_for_one, name: SemanticGraph.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

**Deliverable:** Integrated supervision tree

---

## Phase 4: Ratatouille TUI Implementation (Week 4-5)

### 4.1 Basic TUI Structure and State

**Priority:** CRITICAL
**Effort:** 6 hours
**Dependencies:** 2.3

**Tasks:**
- [ ] Create `lib/semantic_graph/tui.ex`
- [ ] Implement Ratatouille.App behavior
- [ ] Define TUI state struct (port from ui.zig)
- [ ] Implement init/1 callback
- [ ] Implement update/2 callback skeleton
- [ ] Implement render/1 callback skeleton
- [ ] Add basic mode enum (help, input, analyzing, viewing_graph)

**Implementation:**
```elixir
# lib/semantic_graph/tui.ex
defmodule SemanticGraph.TUI do
  @moduledoc """
  Terminal UI for semantic graph application.
  Built with Ratatouille - maintains Zig TUI experience.

  Ports functionality from src/ui.zig
  """

  @behaviour Ratatouille.App

  import Ratatouille.View
  import Ratatouille.Constants, only: [key: 1, color: 1, attribute: 1]

  alias SemanticGraph.GraphAPI
  alias SemanticGraph.Resources.{Vertex, Edge}

  # State struct - mirrors ui.zig:10-19
  defmodule State do
    @type mode :: :help | :input | :analyzing | :viewing_graph

    @type t :: %__MODULE__{
      mode: mode(),
      ideas: list(String.t()),
      current_input: String.t(),
      selected_edge: non_neg_integer() | nil,
      error_message: String.t() | nil,
      graph: map() | nil,
      analyzing: boolean(),
      frame_count: non_neg_integer()
    }

    defstruct mode: :help,
              ideas: [],
              current_input: "",
              selected_edge: nil,
              error_message: nil,
              graph: nil,
              analyzing: false,
              frame_count: 0
  end

  # Ratatouille Callbacks

  @impl true
  def init(_context) do
    # Load existing graph data if any
    vertices = Vertex.list_all!()

    %State{
      ideas: Enum.map(vertices, & &1.content),
      graph: if length(vertices) > 0 do
        %{vertices: vertices, edges: Edge.list_all!()}
      end
    }
  end

  @impl true
  def update(model, msg) do
    # Increment frame counter for animations
    model = %{model | frame_count: model.frame_count + 1}

    # Handle events based on current mode
    case {model.mode, msg} do
      # Help mode handlers (port from ui.zig:65-78)
      {:help, {:event, %{ch: ?e}}} ->
        %{model | mode: :input, current_input: "", error_message: nil}

      {:help, {:event, %{ch: ?v}}} when length(model.ideas) > 0 ->
        %{model | mode: :viewing_graph, selected_edge: nil}

      {:help, {:event, %{ch: ?r}}} ->
        # TODO: Add confirmation dialog (Phase 4.4)
        reset_graph()
        %{model | ideas: [], graph: nil, mode: :help}

      {:help, {:event, %{ch: ?q}}} ->
        Ratatouille.Runtime.shutdown()
        model

      # Input mode handlers (port from ui.zig:80-119)
      {:input, {:event, %{key: key(:enter)}}} when model.current_input != "" ->
        handle_idea_submission(model)

      {:input, {:event, %{key: key(:esc)}}} ->
        %{model | mode: :help, current_input: "", error_message: nil}

      {:input, {:event, %{key: key(:backspace)}}} ->
        %{model | current_input: String.slice(model.current_input, 0..-2//1)}

      {:input, {:event, %{ch: ch}}} when ch >= 32 and ch < 127 ->
        %{model | current_input: model.current_input <> <<ch::utf8>>}

      # Viewing graph mode (port from ui.zig:130-158)
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

  @impl true
  def render(model) do
    case model.mode do
      :help -> render_help(model)
      :input -> render_input(model)
      :analyzing -> render_analyzing(model)
      :viewing_graph -> render_graph(model)
    end
  end

  # Rendering Functions (to be implemented in 4.2-4.3)

  defp render_help(model), do: panel(title: "Help", do: [])
  defp render_input(model), do: panel(title: "Input", do: [])
  defp render_analyzing(model), do: panel(title: "Analyzing", do: [])
  defp render_graph(model), do: panel(title: "Graph", do: [])

  # Helper Functions

  defp handle_idea_submission(model) do
    # TODO: Implement in Phase 4.5 (async analysis)
    model
  end

  defp reset_graph do
    Vertex.list_all!()
    |> Enum.each(&Ash.destroy!/1)
  end

  defp move_selection(nil, :down, graph) when is_map(graph) and map_size(graph.edges) > 0, do: 0
  defp move_selection(nil, :up, _graph), do: nil
  defp move_selection(idx, :up, _graph) when idx > 0, do: idx - 1
  defp move_selection(idx, :up, _graph), do: idx
  defp move_selection(idx, :down, graph) when idx < length(graph.edges) - 1, do: idx + 1
  defp move_selection(idx, :down, _graph), do: idx
end
```

**Deliverable:** TUI skeleton with mode switching

---

### 4.2 Render Help Screen

**Priority:** HIGH
**Effort:** 3 hours
**Dependencies:** 4.1

**Tasks:**
- [ ] Port help screen layout from ui.zig:225-288
- [ ] Display welcome message and instructions
- [ ] Show current status (ideas count, relationships count)
- [ ] List available commands with key bindings
- [ ] Display user's ideas if any exist
- [ ] Add color coding (yellow for headers, cyan for ideas, etc.)

**Implementation:**
```elixir
# Add to lib/semantic_graph/tui.ex

defp render_help(model) do
  view do
    panel title: "Semantic Relationship Graph Analyzer", height: :fill do
      row do
        column(size: 12) do
          label(content: "")
          label(content: "Welcome! Enter ideas one at a time and watch your semantic graph grow.")
          label(content: "Each new idea is analyzed against all existing ideas to discover relationships.")
          label(content: "")

          label(content: "Status:", attributes: [color(:yellow)])

          ideas_count = length(model.ideas)
          label(
            content: "  Ideas in graph: #{ideas_count}",
            attributes: [color(if ideas_count > 0, do: :green, else: :white)]
          )

          edges_count = if model.graph, do: length(model.graph.edges), else: 0
          label(
            content: "  Relationships found: #{edges_count}",
            attributes: [color(if edges_count > 0, do: :green, else: :white)]
          )

          label(content: "")
          label(content: "Commands:", attributes: [color(:yellow)])
          label(content: "  [e] - Enter a new idea")

          if ideas_count > 0 do
            label(content: "  [v] - View graph")
          else
            label(content: "  [v] - View graph (disabled - add ideas first)",
              attributes: [color(:red)])
          end

          label(content: "  [r] - Reset all data")
          label(content: "  [q] - Quit")

          if ideas_count > 0 do
            label(content: "")
            label(content: "Your Ideas:", attributes: [color(:cyan)])

            for {idea, idx} <- Enum.with_index(model.ideas, 1) do
              label(content: "  #{idx}. #{idea}")
            end
          end

          # Show Graphiti status
          if SemanticGraph.Graphiti.Integration.enabled?() do
            label(content: "")
            label(content: "Graphiti: ✓ Connected", attributes: [color(:green)])
          else
            label(content: "")
            label(content: "Graphiti: ✗ Unavailable (using fallback mode)",
              attributes: [color(:yellow)])
          end
        end
      end
    end
  end
end
```

**Deliverable:** Fully functional help screen

---

### 4.3 Render Input, Analyzing, and Graph Screens

**Priority:** HIGH
**Effort:** 6 hours
**Dependencies:** 4.2

**Tasks:**
- [ ] Implement render_input/1 (port from ui.zig:291-333)
- [ ] Implement render_analyzing/1 with spinner (port from ui.zig:336-351)
- [ ] Implement render_graph/1 with edge list (port from ui.zig:354-484)
- [ ] Add relationship symbol mapping
- [ ] Add color coding for selected edges
- [ ] Display relationship legend

**Implementation:**
```elixir
# Add to lib/semantic_graph/tui.ex

defp render_input(model) do
  title_text = if length(model.ideas) == 0 do
    "Enter your first idea"
  else
    "Enter another idea (#{length(model.ideas)} existing)"
  end

  view do
    panel title: title_text, height: :fill do
      row do
        column(size: 12) do
          if length(model.ideas) > 0 do
            label(content: "Your new idea will be compared to all #{length(model.ideas)} existing ideas")
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
  end
end

defp render_analyzing(model) do
  # Animated spinner: ⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏
  spinners = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
  spinner = Enum.at(spinners, rem(model.frame_count, length(spinners)))

  view do
    panel title: "Analyzing", height: :fill do
      row do
        column(size: 12) do
          label(content: "")
          label(
            content: "   #{spinner} Analyzing semantic relationships...",
            attributes: [color(:yellow)]
          )
          label(content: "   Please wait while the LLM processes your idea.")
          label(content: "")
          label(content: "   [Esc] Cancel analysis", attributes: [color(:white)])
        end
      end
    end
  end
end

defp render_graph(model) do
  view do
    panel title: "Semantic Relationship Graph", height: :fill do
      row do
        column(size: 12) do
          # Render vertices
          label(content: "Vertices:", attributes: [color(:cyan)])
          for vertex <- model.graph.vertices do
            label(content: "  • #{vertex.content}")
          end

          label(content: "")
          label(content: "Relationships:", attributes: [color(:cyan)])

          # Render edges with selection
          for {edge, idx} <- Enum.with_index(model.graph.edges) do
            is_selected = model.selected_edge == idx
            attrs = if is_selected,
              do: [color(:black), attribute(:reverse)],
              else: []

            from = Enum.find(model.graph.vertices, &(&1.id == edge.from_vertex_id))
            to = Enum.find(model.graph.vertices, &(&1.id == edge.to_vertex_id))
            symbol = relationship_symbol(edge.relation_type)

            content = "  #{truncate(from.content, 30)} #{symbol} #{truncate(to.content, 30)} (#{Float.round(edge.certainty, 2)})"
            label(content: content, attributes: attrs)
          end

          label(content: "")
          label(content: "Legend:", attributes: [color(:yellow)])
          label(content: "  → Implicative  ⊆ Hierarchical  ⇒ Causal")
          label(content: "  ⊥ Contradictory  ≡ Synonymous  ≈ Analogous")

          label(content: "")
          label(content: "[↑↓] Navigate  [h/Esc] Menu  [q] Quit",
            attributes: [color(:white)])
        end
      end
    end
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

defp truncate(text, max_length) do
  if String.length(text) > max_length do
    String.slice(text, 0, max_length - 3) <> "..."
  else
    text
  end
end
```

**Deliverable:** Complete TUI rendering

---

### 4.4 Integrate TUI with Application

**Priority:** HIGH
**Effort:** 2 hours
**Dependencies:** 4.3

**Tasks:**
- [ ] Update application.ex to start Ratatouille
- [ ] Configure TUI runtime with proper shutdown
- [ ] Test TUI startup and graceful shutdown
- [ ] Ensure TUI interacts correctly with Ash resources

**Implementation:**
```elixir
# Update lib/semantic_graph/application.ex

def start(_type, _args) do
  children = [
    SemanticGraph.GraphAPI,
    {SemanticGraph.Graphiti.Integration, []},

    # Start Ratatouille TUI
    {Ratatouille.Runtime.Supervisor,
      runtime: [
        app: SemanticGraph.TUI,
        shutdown: {:application, :semantic_graph},
        quit_events: [
          {:key, Ratatouille.Constants.key(:ctrl_c)},
          {:key, Ratatouille.Constants.key(:ctrl_d)}
        ]
      ]}
  ]

  opts = [strategy: :one_for_one, name: SemanticGraph.Supervisor]
  Supervisor.start_link(children, opts)
end
```

**Validation:**
```bash
mix run --no-halt
# Should display TUI help screen
# Press 'q' to quit
```

**Deliverable:** Runnable TUI application

---

### 4.5 Implement Async LLM Analysis

**Priority:** CRITICAL
**Effort:** 10 hours
**Dependencies:** 4.4

**Tasks:**
- [ ] Create `lib/semantic_graph/llm/client.ex` (port from llm.zig)
- [ ] Implement Tesla-based LLM client with retry logic
- [ ] Support multiple providers (Anthropic, OpenAI, custom)
- [ ] Create `lib/semantic_graph/analysis/service.ex` (port from analysis_service.zig)
- [ ] Implement async Task-based analysis
- [ ] Add cancellation support
- [ ] Integrate with TUI state machine
- [ ] Handle analysis completion and errors

**Implementation (LLM Client):**
```elixir
# lib/semantic_graph/llm/client.ex
defmodule SemanticGraph.LLM.Client do
  @moduledoc """
  LLM client for relationship analysis.
  Ports functionality from src/llm.zig
  """

  use Tesla

  defmodule Config do
    defstruct [
      provider: :anthropic,
      model: nil,
      api_key: nil,
      endpoint: nil,
      max_retries: 3
    ]

    def from_env do
      provider = System.get_env("LLM_PROVIDER", "anthropic") |> String.to_atom()

      %__MODULE__{
        provider: provider,
        model: get_model(provider),
        api_key: get_api_key(provider),
        endpoint: get_endpoint(provider)
      }
    end

    defp get_model(:anthropic), do: System.get_env("LLM_MODEL", "claude-3-5-sonnet-20241022")
    defp get_model(:openai), do: System.get_env("LLM_MODEL", "gpt-4")
    defp get_model(:custom), do: System.get_env("LLM_MODEL", "llama3")

    defp get_api_key(:anthropic), do: System.get_env("ANTHROPIC_API_KEY")
    defp get_api_key(:openai), do: System.get_env("OPENAI_API_KEY")
    defp get_api_key(:custom), do: System.get_env("LLM_API_KEY")

    defp get_endpoint(:anthropic), do: "https://api.anthropic.com/v1"
    defp get_endpoint(:openai), do: "https://api.openai.com/v1"
    defp get_endpoint(:custom), do: System.get_env("LLM_API_ENDPOINT", "http://localhost:8000")
  end

  plug Tesla.Middleware.BaseUrl, fn -> Config.from_env().endpoint end
  plug Tesla.Middleware.JSON
  plug Tesla.Middleware.Retry, delay: 1000, max_retries: 3
  plug Tesla.Middleware.Timeout, timeout: 30_000

  @doc """
  Analyze relationships between a new concept and existing concepts.
  Returns list of relationships.
  """
  def analyze_relationships(new_concept, existing_concepts) do
    config = Config.from_env()

    if config.api_key do
      prompt = build_prompt(new_concept, existing_concepts)

      case call_llm(config, prompt) do
        {:ok, response} -> parse_relationships(response)
        {:error, reason} -> {:error, reason}
      end
    else
      # Fall back to mock data when no API key
      generate_mock_relationships(new_concept, existing_concepts)
    end
  end

  defp call_llm(%Config{provider: :anthropic} = config, prompt) do
    headers = [
      {"x-api-key", config.api_key},
      {"anthropic-version", "2023-06-01"}
    ]

    body = %{
      model: config.model,
      max_tokens: 4096,
      messages: [%{role: "user", content: prompt}]
    }

    case post("/messages", body, headers: headers) do
      {:ok, %{status: 200, body: response}} ->
        content = response["content"] |> List.first() |> Map.get("text")
        {:ok, content}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_prompt(new_concept, existing_concepts) do
    """
    Analyze the semantic relationships between the new concept and existing concepts.

    NEW CONCEPT:
    #{new_concept}

    EXISTING CONCEPTS:
    #{Enum.map_join(existing_concepts, "\n", &("- " <> &1))}

    For each relevant relationship, provide:
    1. From concept
    2. To concept
    3. Relationship type (one of: contradictory, implicative, hierarchical, evolutionary, analogous, synonymous, antonymous, part_whole, causal)
    4. Certainty (0.0 to 1.0)
    5. Description

    Format your response as JSON array of objects with fields: from, to, type, certainty, description.
    """
  end

  defp parse_relationships(response_text) do
    case Jason.decode(response_text) do
      {:ok, relationships} when is_list(relationships) ->
        {:ok, Enum.map(relationships, &map_relationship/1)}

      _ ->
        {:error, :parse_error}
    end
  end

  defp map_relationship(data) do
    %{
      from: data["from"],
      to: data["to"],
      type: String.to_atom(data["type"]),
      certainty: data["certainty"],
      description: data["description"]
    }
  end

  defp generate_mock_relationships(new_concept, existing_concepts) do
    # Simple mock for testing without API key
    relationships = existing_concepts
    |> Enum.take(2)
    |> Enum.map(fn existing ->
      %{
        from: new_concept,
        to: existing,
        type: :analogous,
        certainty: 0.75,
        description: "Mock relationship for testing"
      }
    end)

    {:ok, relationships}
  end
end
```

**Implementation (Analysis Service):**
```elixir
# lib/semantic_graph/analysis/service.ex
defmodule SemanticGraph.Analysis.Service do
  @moduledoc """
  Orchestrates semantic analysis workflow.
  Ports functionality from src/analysis_service.zig
  """

  alias SemanticGraph.LLM.Client
  alias SemanticGraph.Resources.{Vertex, Edge}
  alias SemanticGraph.Graphiti

  @doc """
  Analyze a new idea against all existing ideas.
  Returns Task for async execution.
  """
  def analyze_new_idea_async(content) do
    Task.async(fn ->
      analyze_new_idea(content)
    end)
  end

  @doc """
  Synchronous version of analyze_new_idea.
  Creates vertex, analyzes relationships, creates edges.
  """
  def analyze_new_idea(content) do
    # 1. Create new vertex
    {:ok, vertex} = Vertex.add_idea(%{content: content, group: 0})

    # 2. Get all existing vertices (excluding the new one)
    existing_vertices =
      Vertex.list_all!()
      |> Enum.reject(&(&1.id == vertex.id))

    if length(existing_vertices) == 0 do
      # First idea, no relationships to analyze
      {:ok, %{vertex: vertex, relationships: []}}
    else
      # 3. Analyze relationships using LLM
      existing_contents = Enum.map(existing_vertices, & &1.content)

      {:ok, llm_relationships} = Client.analyze_relationships(content, existing_contents)

      # 4. Optionally enhance with Graphiti
      graphiti_relationships = case Graphiti.Integration.enhance_relationships(content, existing_contents) do
        {:ok, rels} -> rels
        _ -> []
      end

      # 5. Combine and deduplicate relationships
      all_relationships = llm_relationships ++ graphiti_relationships

      # 6. Create edges in graph
      edges = Enum.map(all_relationships, fn rel ->
        from_vertex = find_vertex_by_content(rel.from, [vertex | existing_vertices])
        to_vertex = find_vertex_by_content(rel.to, [vertex | existing_vertices])

        if from_vertex && to_vertex do
          case Edge.add_relationship(%{
            from_vertex_id: from_vertex.id,
            to_vertex_id: to_vertex.id,
            relation_type: rel.type,
            certainty: rel.certainty,
            description: rel.description
          }) do
            {:ok, edge} -> edge
            _ -> nil
          end
        end
      end)
      |> Enum.reject(&is_nil/1)

      # 7. Sync to Graphiti for temporal knowledge
      Graphiti.Integration.sync_concept(content)

      {:ok, %{vertex: vertex, relationships: edges}}
    end
  end

  defp find_vertex_by_content(content, vertices) do
    Enum.find(vertices, fn v ->
      String.downcase(String.trim(v.content)) == String.downcase(String.trim(content))
    end)
  end
end
```

**Update TUI to use async analysis:**
```elixir
# Update lib/semantic_graph/tui.ex

defmodule State do
  # Add analysis_task field
  defstruct mode: :help,
            ideas: [],
            current_input: "",
            selected_edge: nil,
            error_message: nil,
            graph: nil,
            analyzing: false,
            analysis_task: nil,  # NEW
            frame_count: 0
end

defp handle_idea_submission(model) do
  content = String.trim(model.current_input)

  if valid_idea?(content) do
    # Start async analysis
    task = SemanticGraph.Analysis.Service.analyze_new_idea_async(content)

    %{model |
      mode: :analyzing,
      current_input: "",
      analysis_task: task,
      error_message: nil
    }
  else
    %{model | error_message: "Invalid input (1-1000 characters required)"}
  end
end

# Add subscription to check for task completion
@impl true
def subscribe(_model) do
  Ratatouille.Runtime.subscribe(:timer, 100)  # Check every 100ms
end

# Handle timer events to check task status
@impl true
def update(model, {:timer, _}) do
  if model.mode == :analyzing && model.analysis_task do
    case Task.yield(model.analysis_task, 0) do
      {:ok, {:ok, result}} ->
        # Analysis complete - update graph
        %{model |
          mode: :viewing_graph,
          ideas: [result.vertex.content | model.ideas],
          graph: %{
            vertices: Vertex.list_all!(),
            edges: Edge.list_all!()
          },
          analysis_task: nil
        }

      {:ok, {:error, reason}} ->
        # Analysis failed
        %{model |
          mode: :input,
          error_message: "Analysis failed: #{inspect(reason)}",
          analysis_task: nil
        }

      nil ->
        # Still running, keep waiting
        model
    end
  else
    model
  end
end

defp valid_idea?(content) do
  length = String.length(content)
  length >= 1 && length <= 1000
end
```

**Deliverable:** Fully async LLM integration

---

## Phase 5: MCP Protocol Support (Week 6)

### 5.1 Implement JSON-RPC 2.0 Handler

**Priority:** HIGH
**Effort:** 6 hours
**Dependencies:** 2.3

**Tasks:**
- [ ] Create `lib/semantic_graph_web/plugs/jsonrpc.ex`
- [ ] Implement JSON-RPC 2.0 request validation
- [ ] Add error code mapping (per spec)
- [ ] Handle batch requests
- [ ] Write comprehensive tests

**Implementation:**
```elixir
# lib/semantic_graph_web/plugs/jsonrpc.ex
defmodule SemanticGraphWeb.Plugs.JSONRPC do
  @moduledoc """
  JSON-RPC 2.0 protocol handler for MCP.
  Ports functionality from src/mcp_server.zig
  """

  import Plug.Conn

  @jsonrpc_version "2.0"

  def init(opts), do: opts

  def call(conn, _opts) do
    with {:ok, body, conn} <- read_body(conn),
         {:ok, request} <- Jason.decode(body),
         :ok <- validate_request(request) do

      response = handle_request(request)

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(response))
    else
      {:error, :invalid_request} ->
        error_response(conn, -32600, "Invalid Request", nil)

      {:error, :parse_error} ->
        error_response(conn, -32700, "Parse error", nil)

      error ->
        error_response(conn, -32603, "Internal error", nil)
    end
  end

  defp validate_request(%{"jsonrpc" => @jsonrpc_version, "method" => _, "id" => _}), do: :ok
  defp validate_request(_), do: {:error, :invalid_request}

  defp handle_request(%{"method" => method, "params" => params, "id" => id}) do
    case route_method(method, params) do
      {:ok, result} ->
        %{
          jsonrpc: @jsonrpc_version,
          result: result,
          id: id
        }

      {:error, code, message} ->
        %{
          jsonrpc: @jsonrpc_version,
          error: %{code: code, message: message},
          id: id
        }
    end
  end

  defp route_method("tools/list", _params) do
    {:ok, %{
      tools: [
        %{
          name: "add_idea",
          description: "Add a new idea/concept to the graph",
          inputSchema: %{
            type: "object",
            properties: %{
              content: %{type: "string", description: "The idea content"}
            },
            required: ["content"]
          }
        },
        %{
          name: "analyze_idea",
          description: "Analyze relationships for a new idea",
          inputSchema: %{
            type: "object",
            properties: %{
              content: %{type: "string"}
            },
            required: ["content"]
          }
        },
        %{
          name: "list_ideas",
          description: "List all ideas in the graph",
          inputSchema: %{type: "object", properties: %{}}
        }
      ]
    }}
  end

  defp route_method("tools/call", %{"name" => tool, "arguments" => args}) do
    SemanticGraphWeb.MCPController.call_tool(tool, args)
  end

  defp route_method(_, _), do: {:error, -32601, "Method not found"}

  defp error_response(conn, code, message, id) do
    response = %{
      jsonrpc: @jsonrpc_version,
      error: %{code: code, message: message},
      id: id
    }

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(response))
  end
end
```

**Deliverable:** JSON-RPC 2.0 compliant handler

---

### 5.2 Implement MCP Controller

**Priority:** HIGH
**Effort:** 8 hours
**Dependencies:** 5.1

**Tasks:**
- [ ] Create `lib/semantic_graph_web/controllers/mcp_controller.ex`
- [ ] Implement all MCP tools (add_idea, analyze_idea, list_ideas, etc.)
- [ ] Port tool handlers from mcp_server.zig
- [ ] Add proper error handling
- [ ] Write integration tests

**Implementation:**
```elixir
# lib/semantic_graph_web/controllers/mcp_controller.ex
defmodule SemanticGraphWeb.MCPController do
  @moduledoc """
  MCP tool handlers.
  Ports functionality from src/mcp_server.zig
  """

  alias SemanticGraph.Resources.{Vertex, Edge}
  alias SemanticGraph.Analysis.Service

  def call_tool("add_idea", %{"content" => content}) do
    case Vertex.add_idea(%{content: content}) do
      {:ok, vertex} ->
        {:ok, %{
          content: [%{
            type: "text",
            text: "Added idea: #{vertex.content}"
          }]
        }}

      {:error, error} ->
        {:error, -32000, "Failed to add idea: #{inspect(error)}"}
    end
  end

  def call_tool("analyze_idea", %{"content" => content}) do
    case Service.analyze_new_idea(content) do
      {:ok, result} ->
        rel_count = length(result.relationships)
        {:ok, %{
          content: [%{
            type: "text",
            text: "Analyzed '#{content}' - found #{rel_count} relationships"
          }]
        }}

      {:error, reason} ->
        {:error, -32000, "Analysis failed: #{inspect(reason)}"}
    end
  end

  def call_tool("list_ideas", _args) do
    vertices = Vertex.list_all!()

    ideas_text = vertices
    |> Enum.map_join("\n", &("- " <> &1.content))

    {:ok, %{
      content: [%{
        type: "text",
        text: "Ideas (#{length(vertices)}):\n#{ideas_text}"
      }]
    }}
  end

  def call_tool("reset_graph", _args) do
    Vertex.list_all!()
    |> Enum.each(&Ash.destroy!/1)

    {:ok, %{
      content: [%{
        type: "text",
        text: "Graph reset successfully"
      }]
    }}
  end

  def call_tool(tool_name, _args) do
    {:error, -32601, "Unknown tool: #{tool_name}"}
  end
end
```

**Deliverable:** Full MCP tool suite

---

### 5.3 Phoenix Router and Endpoint

**Priority:** HIGH
**Effort:** 4 hours
**Dependencies:** 5.2

**Tasks:**
- [ ] Create `lib/semantic_graph_web/router.ex`
- [ ] Add MCP route with JSONRPC plug
- [ ] Configure Phoenix endpoint
- [ ] Add CORS support if needed
- [ ] Test with curl and Claude Desktop

**Implementation:**
```elixir
# lib/semantic_graph_web/router.ex
defmodule SemanticGraphWeb.Router do
  use Phoenix.Router

  pipeline :mcp do
    plug :accepts, ["json"]
    plug SemanticGraphWeb.Plugs.JSONRPC
  end

  scope "/", SemanticGraphWeb do
    pipe_through :mcp

    post "/mcp", MCPController, :handle_request
  end

  # Health check endpoint
  get "/health", SemanticGraphWeb.HealthController, :index
end

# lib/semantic_graph_web/endpoint.ex
defmodule SemanticGraphWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :semantic_graph

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:json],
    pass: ["*/*"],
    json_decoder: Jason

  plug SemanticGraphWeb.Router
end
```

**Validation:**
```bash
# Start Phoenix server
mix phx.server

# Test MCP endpoint
curl -X POST http://localhost:4000/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/list",
    "params": {},
    "id": 1
  }'
```

**Deliverable:** Running MCP HTTP server

---

## Phase 6: Integration and Testing (Week 7)

### 6.1 End-to-End Integration Tests

**Priority:** HIGH
**Effort:** 12 hours
**Dependencies:** All previous phases

**Tasks:**
- [ ] Create integration test suite in `test/integration/`
- [ ] Test TUI workflow (help → input → analyze → view)
- [ ] Test MCP tool calls end-to-end
- [ ] Test Graphiti integration (with mock service)
- [ ] Test fallback modes (Graphiti unavailable)
- [ ] Test concurrent MCP requests
- [ ] Test graph persistence across restarts

**Test Structure:**
```
test/
├── integration/
│   ├── tui_workflow_test.exs
│   ├── mcp_protocol_test.exs
│   ├── graphiti_integration_test.exs
│   └── concurrent_access_test.exs
├── semantic_graph/
│   ├── resources/
│   │   ├── vertex_test.exs
│   │   └── edge_test.exs
│   ├── analysis/
│   │   └── service_test.exs
│   ├── llm/
│   │   └── client_test.exs
│   └── graphiti/
│       ├── client_test.exs
│       └── integration_test.exs
└── semantic_graph_web/
    ├── controllers/
    │   └── mcp_controller_test.exs
    └── plugs/
        └── jsonrpc_test.exs
```

**Example Integration Test:**
```elixir
# test/integration/tui_workflow_test.exs
defmodule Integration.TUIWorkflowTest do
  use ExUnit.Case

  alias SemanticGraph.Resources.{Vertex, Edge}
  alias SemanticGraph.Analysis.Service

  setup do
    # Clean graph before each test
    Vertex.list_all!() |> Enum.each(&Ash.destroy!/1)
    :ok
  end

  test "complete workflow: add ideas, analyze, view graph" do
    # Add first idea
    {:ok, v1} = Vertex.add_idea(%{content: "Machine learning"})
    assert v1.content == "Machine learning"

    # Add and analyze second idea
    {:ok, result} = Service.analyze_new_idea("Deep learning")

    assert result.vertex.content == "Deep learning"
    assert length(result.relationships) > 0

    # Verify graph state
    vertices = Vertex.list_all!()
    assert length(vertices) == 2

    edges = Edge.list_all!()
    assert length(edges) > 0
  end

  test "handles empty graph" do
    vertices = Vertex.list_all!()
    assert vertices == []
  end

  test "prevents duplicate relationships with certainty check" do
    {:ok, v1} = Vertex.add_idea(%{content: "A"})
    {:ok, v2} = Vertex.add_idea(%{content: "B"})

    # Add relationship with certainty 0.7
    {:ok, edge1} = Edge.add_relationship(%{
      from_vertex_id: v1.id,
      to_vertex_id: v2.id,
      relation_type: :analogous,
      certainty: 0.7,
      description: "First"
    })

    # Try to add duplicate with lower certainty - should reject
    result = Edge.add_relationship(%{
      from_vertex_id: v1.id,
      to_vertex_id: v2.id,
      relation_type: :analogous,
      certainty: 0.5,
      description: "Second"
    })

    assert {:error, _} = result

    # Add duplicate with higher certainty - should update
    {:ok, edge2} = Edge.add_relationship(%{
      from_vertex_id: v1.id,
      to_vertex_id: v2.id,
      relation_type: :analogous,
      certainty: 0.9,
      description: "Better"
    })

    # Should have only one edge
    edges = Edge.list_all!()
    assert length(edges) == 1
    assert List.first(edges).certainty == 0.9
  end
end
```

**Deliverable:** Comprehensive test coverage

---

### 6.2 Performance Testing and Optimization

**Priority:** MEDIUM
**Effort:** 8 hours
**Dependencies:** 6.1

**Tasks:**
- [ ] Benchmark vertex/edge operations
- [ ] Test graph with 100+ vertices
- [ ] Profile memory usage
- [ ] Optimize ETS table access patterns
- [ ] Add caching for frequently accessed data
- [ ] Test Graphiti service under load

**Deliverable:** Performance baseline and optimizations

---

### 6.3 Documentation

**Priority:** HIGH
**Effort:** 10 hours
**Dependencies:** 6.1

**Tasks:**
- [ ] Write installation guide
- [ ] Document architecture decisions
- [ ] Create API documentation with ExDoc
- [ ] Write deployment guide (Docker, Fly.io, etc.)
- [ ] Document Graphiti setup
- [ ] Create troubleshooting guide
- [ ] Update README with new architecture

**Deliverable:** Complete documentation suite

---

## Phase 7: Production Readiness (Week 8-9)

### 7.1 Docker Deployment

**Priority:** HIGH
**Effort:** 6 hours
**Dependencies:** All phases

**Tasks:**
- [ ] Create `Dockerfile` for Elixir app
- [ ] Create `Dockerfile` for Graphiti service
- [ ] Update `docker-compose.yml` with all services
- [ ] Add healthchecks
- [ ] Test full stack deployment
- [ ] Document deployment process

**Deliverable:** Production-ready Docker setup

---

### 7.2 Monitoring and Observability

**Priority:** MEDIUM
**Effort:** 8 hours
**Dependencies:** 7.1

**Tasks:**
- [ ] Add Telemetry instrumentation
- [ ] Set up logging with Logger
- [ ] Add metrics collection (Prometheus compatible)
- [ ] Create health check endpoints
- [ ] Add error tracking (Sentry, AppSignal, etc.)
- [ ] Document observability setup

**Deliverable:** Production monitoring

---

### 7.3 Security Hardening

**Priority:** HIGH
**Effort:** 6 hours
**Dependencies:** All phases

**Tasks:**
- [ ] Add rate limiting to MCP endpoint
- [ ] Implement API authentication (optional)
- [ ] Sanitize all user inputs
- [ ] Add HTTPS/TLS configuration
- [ ] Security audit of dependencies
- [ ] Document security best practices

**Deliverable:** Hardened production deployment

---

## Summary

### Total Effort Estimate

| Phase | Description | Effort | Weeks |
|-------|-------------|--------|-------|
| 1 | Foundation Setup | 12h | 1 |
| 2 | Core Domain (Ash Resources) | 12h | 1 |
| 3 | Graphiti Integration | 16h | 1 |
| 4 | Ratatouille TUI | 29h | 2 |
| 5 | MCP Protocol Support | 18h | 1 |
| 6 | Integration & Testing | 30h | 1.5 |
| 7 | Production Readiness | 20h | 1.5 |
| **Total** | | **137h** | **9 weeks** |

### Critical Path

1. **Week 1**: Foundation + Domain (Phases 1-2)
2. **Week 2**: Domain completion + Graphiti start (Phase 2-3)
3. **Week 3**: Graphiti completion (Phase 3)
4. **Week 4-5**: TUI Implementation (Phase 4)
5. **Week 6**: MCP Protocol (Phase 5)
6. **Week 7**: Testing (Phase 6)
7. **Week 8-9**: Production (Phase 7)

### Key Risks

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Graphiti integration complexity | HIGH | Detailed mock testing, fallback mode |
| TUI async analysis | HIGH | Incremental implementation, thorough testing |
| Performance at scale | MEDIUM | Early benchmarking, ETS optimization |
| Team Elixir knowledge | HIGH | Training, pair programming, documentation |

### Dependencies

**External Services:**
- Neo4j (via Docker)
- Graphiti Python service
- LLM API (Anthropic/OpenAI)

**Elixir Libraries:**
- Phoenix
- Ash Framework
- Ratatouille
- Tesla
- Jason

### Success Criteria

- [ ] TUI maintains feature parity with Zig version
- [ ] Graphiti integration working with graceful fallback
- [ ] MCP protocol fully functional
- [ ] All tests passing (>90% coverage)
- [ ] Performance acceptable (<100ms for UI operations)
- [ ] Documentation complete
- [ ] Production deployment successful

---

## Next Steps

1. **Decision Point**: Stakeholder approval of Option C
2. **Prototyping** (3-4 days):
   - Day 1: Phoenix + Ash setup with basic resources
   - Day 2: Graphiti service integration
   - Day 3: Ratatouille TUI prototype
   - Day 4: Evaluation
3. **If approved**: Begin Phase 1 implementation

---

**Last Updated:** 2025-11-22
**Document Owner:** Architecture Team
**Related Documents:**
- [ADR-006: Graphiti Integration](./architecture/ADR-006-graphiti-knowledge-graph-integration.md)
- [Elixir/Ash Feasibility Study](./ELIXIR_ASH_FEASIBILITY.md)
