# SemanticGraph - Elixir/Ash Implementation

A hybrid architecture combining Elixir/Ash backend, Graphiti knowledge graph, and Ratatouille TUI for semantic relationship analysis.

## Architecture Overview

This is **Option C** from the feasibility study - a hybrid approach that maximizes the strengths of each technology:

- **Elixir/Ash**: Declarative resources, OTP concurrency, fault tolerance
- **Graphiti**: Temporal knowledge graphs, LLM-powered entity extraction, episodic memory
- **Ratatouille**: Terminal-first UI maintaining current UX
- **Neo4j/FalkorDB**: Production-grade graph database backend

## Project Structure

```
semantic_graph/
├── lib/
│   ├── semantic_graph/
│   │   ├── application.ex           # OTP application
│   │   ├── resources/                # Ash resources (Phase 2)
│   │   │   ├── vertex.ex
│   │   │   └── edge.ex
│   │   ├── graph_api.ex              # Ash domain (Phase 2)
│   │   ├── graphiti/                 # Graphiti integration (Phase 3)
│   │   │   ├── client.ex
│   │   │   └── integration.ex
│   │   ├── llm/                      # LLM client (Phase 4)
│   │   │   └── client.ex
│   │   ├── analysis/                 # Analysis service (Phase 4)
│   │   │   └── service.ex
│   │   └── tui.ex                    # Ratatouille TUI (Phase 4)
│   └── semantic_graph_web/
│       ├── controllers/              # MCP controller (Phase 5)
│       ├── plugs/                    # JSON-RPC plug (Phase 5)
│       ├── endpoint.ex
│       ├── router.ex
│       └── telemetry.ex
├── config/
│   ├── config.exs
│   ├── dev.exs
│   ├── test.exs
│   └── runtime.exs
├── test/
├── mix.exs
└── README.md
```

## Prerequisites

- Elixir 1.14+ and Erlang/OTP 25+
- Phoenix 1.7+
- Docker and Docker Compose (for Graphiti and Neo4j)
- Python 3.10+ (for Graphiti service)

## Getting Started

### 1. Install Dependencies

```bash
cd semantic_graph
mix deps.get
```

### 2. Set Up Graphiti Service (Phase 1.2)

```bash
# Create Python virtual environment
python -m venv graphiti_service/venv
source graphiti_service/venv/bin/activate

# Install dependencies
pip install fastapi uvicorn graphiti-core neo4j

# Start the service
cd graphiti_service
uvicorn main:app --reload
```

### 3. Start Neo4j with Docker

```bash
docker-compose up -d neo4j
```

### 4. Configure Environment

Copy `.env.example` to `.env` and set:

```bash
# LLM Configuration
ANTHROPIC_API_KEY=your_key_here
LLM_PROVIDER=anthropic
LLM_MODEL=claude-3-5-sonnet-20241022

# Graphiti Configuration
GRAPHITI_BASE_URL=http://localhost:8000
NEO4J_URI=bolt://localhost:7687
NEO4J_USER=neo4j
NEO4J_PASSWORD=password
```

### 5. Run the Application

**TUI Mode (default):**
```bash
mix run --no-halt
```

**Web API Mode (for MCP protocol):**
```bash
mix phx.server
```

## Development Phases

This project is being developed in phases as outlined in `docs/TODO-OPTION-C-HYBRID-ELIXIR-GRAPHITI.md`:

- [x] **Phase 1**: Foundation Setup (Weeks 1)
  - [x] Elixir/Phoenix project setup
  - [ ] Graphiti service setup
  - [ ] Docker Compose configuration

- [ ] **Phase 2**: Core Domain (Week 2)
  - [ ] Vertex resource
  - [ ] Edge resource
  - [ ] GraphAPI domain

- [ ] **Phase 3**: Graphiti Integration (Week 3)
  - [ ] HTTP client
  - [ ] Integration GenServer
  - [ ] Supervision tree

- [ ] **Phase 4**: Ratatouille TUI (Weeks 4-5)
  - [ ] Basic TUI structure
  - [ ] Rendering screens
  - [ ] Async LLM analysis

- [ ] **Phase 5**: MCP Protocol (Week 6)
  - [ ] JSON-RPC handler
  - [ ] MCP controller
  - [ ] Phoenix router integration

- [ ] **Phase 6**: Integration & Testing (Week 7)
- [ ] **Phase 7**: Production Readiness (Weeks 8-9)

## Running Tests

```bash
# Run all tests
mix test

# Run with coverage
mix test --cover

# Run specific test file
mix test test/semantic_graph/resources/vertex_test.exs
```

## Documentation

- [TODO Document](../docs/TODO-OPTION-C-HYBRID-ELIXIR-GRAPHITI.md)
- [Architecture ADR-006](../docs/architecture/ADR-006-graphiti-knowledge-graph-integration.md)
- [Elixir/Ash Feasibility Study](../docs/ELIXIR_ASH_FEASIBILITY.md)

## Related Projects

This is the Elixir/Ash implementation of the Semantic Relationship Graph Analyzer. The original Zig implementation can be found in the parent directory.

## License

See parent project LICENSE file.
