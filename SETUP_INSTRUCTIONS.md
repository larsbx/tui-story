# Setup Instructions - Elixir Implementation

Quick start guide for the Elixir/Ash + Graphiti implementation.

## What Was Created

✅ **Complete Phoenix + Ash project** in `semantic_graph/`
✅ **Complete Graphiti Python service** in `graphiti_service/`
✅ **Docker Compose orchestration** for Neo4j and Graphiti
✅ **Vertex and Edge Ash resources** with full validation
✅ **GraphAPI domain** with convenience methods
✅ **Comprehensive test suite** for all resources
✅ **Development tooling** (Makefile, configs, etc.)

## Prerequisites

Before you can run the project, install:

1. **Elixir** (1.14+) and **Erlang/OTP** (25+)
   ```bash
   # On macOS
   brew install elixir

   # On Ubuntu
   wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb
   sudo dpkg -i erlang-solutions_2.0_all.deb
   sudo apt-get update
   sudo apt-get install esl-erlang elixir
   ```

2. **Phoenix** (1.7+)
   ```bash
   mix archive.install hex phx_new
   ```

3. **Docker** and **Docker Compose**
   - Download from https://www.docker.com/get-started

4. **Python** (3.10+)
   - Should be pre-installed on most systems

## Initial Setup

### Step 1: Configure Environment

```bash
# Copy environment template
cp .env.docker .env

# Edit .env and add your API keys
# Required: ANTHROPIC_API_KEY or OPENAI_API_KEY
```

### Step 2: Start Docker Services

```bash
# Start Neo4j and Graphiti service
make start

# Wait for services to be healthy (30-60 seconds)
make health

# View logs if needed
make logs
```

You should see:
- Neo4j Browser at: http://localhost:7474
- Graphiti API docs at: http://localhost:8000/docs

### Step 3: Set Up Elixir Application

```bash
cd semantic_graph

# Install dependencies
mix deps.get

# Compile the project
mix compile

# Run tests to verify everything works
mix test
```

Expected output:
```
Compiling X files (.ex)
Generated semantic_graph app
...
Finished in X.X seconds (async, seed 0)
XX tests, 0 failures
```

## Verify Installation

### Test the GraphAPI

Start an interactive Elixir shell:

```bash
cd semantic_graph
iex -S mix
```

Run these commands in IEx:

```elixir
# Import the resources
alias SemanticGraph.Resources.{Vertex, Edge}
alias SemanticGraph.GraphAPI

# Create some vertices
{:ok, v1} = Vertex.add_idea(%{content: "Machine learning"})
{:ok, v2} = Vertex.add_idea(%{content: "Deep learning"})
{:ok, v3} = Vertex.add_idea(%{content: "Neural networks"})

# Create relationships
{:ok, edge1} = Edge.add_relationship(%{
  from_vertex_id: v2.id,
  to_vertex_id: v1.id,
  relation_type: :hierarchical,
  certainty: 0.95,
  description: "Deep learning is a subset of machine learning"
})

{:ok, edge2} = Edge.add_relationship(%{
  from_vertex_id: v3.id,
  to_vertex_id: v2.id,
  relation_type: :causal,
  certainty: 0.9,
  description: "Neural networks enable deep learning"
})

# Query the graph
GraphAPI.get_graph_state()
GraphAPI.get_statistics()

# Search vertices
GraphAPI.search_vertices("learning")

# Get high-certainty edges
GraphAPI.get_high_certainty_edges(0.9)

# Test certainty-based deduplication
# This should skip because edge1 already has certainty 0.95
Edge.add_relationship(%{
  from_vertex_id: v2.id,
  to_vertex_id: v1.id,
  relation_type: :hierarchical,
  certainty: 0.7
})

# This should update edge1 to certainty 0.99
Edge.add_relationship(%{
  from_vertex_id: v2.id,
  to_vertex_id: v1.id,
  relation_type: :hierarchical,
  certainty: 0.99
})

# Verify the update
GraphAPI.get_graph_state()
```

### Test the Graphiti Service

```bash
# Health check
curl http://localhost:8000/health | python -m json.tool

# Add an episode
curl -X POST http://localhost:8000/episodes \
  -H "Content-Type: application/json" \
  -d '{
    "content": "Artificial intelligence is transforming technology",
    "source": "test"
  }' | python -m json.tool

# Search
curl -X POST http://localhost:8000/search \
  -H "Content-Type: application/json" \
  -d '{
    "query": "artificial intelligence",
    "limit": 10
  }' | python -m json.tool
```

## Development Workflow

### Common Commands

```bash
# Start all services
make start

# Stop all services
make stop

# View logs
make logs
make logs-neo4j
make logs-graphiti

# Check health
make health

# Run Elixir tests
make test

# Start Elixir shell
make elixir-shell

# Run Elixir app
make elixir-run

# Run only Neo4j (for local dev)
make dev-neo4j

# Run Graphiti locally
make dev-graphiti

# Clean up everything
make clean
```

### Development Mode

**Option A: All in Docker**
```bash
make start
cd semantic_graph && iex -S mix
```

**Option B: Hybrid (Docker + Local)**
```bash
# Start only Neo4j
make dev-neo4j

# In terminal 1: Run Graphiti locally
make dev-graphiti

# In terminal 2: Run Elixir app
make dev-elixir
```

## Troubleshooting

### "Elixir command not found"

Install Elixir following the prerequisites section above.

### "Neo4j won't start" or "Connection refused"

```bash
# Check if port 7687 or 7474 is already in use
lsof -i :7687
lsof -i :7474

# Stop any existing Neo4j instances
docker ps
docker stop <container_id>

# Try again
make clean
make start
```

### "Graphiti service unhealthy"

```bash
# Check logs
make logs-graphiti

# Common issues:
# 1. Neo4j not ready yet - wait 30s more
# 2. Missing API key - check .env file
# 3. Python dependencies - rebuild:
docker-compose build --no-cache graphiti
make start
```

### "Mix dependency errors"

```bash
cd semantic_graph

# Clean and reinstall
rm -rf _build deps
mix deps.clean --all
mix deps.get
mix compile
```

### "Tests failing"

```bash
# Make sure services are running
make health

# Run tests with verbose output
cd semantic_graph
mix test --trace

# Run specific test
mix test test/semantic_graph/resources/vertex_test.exs
```

## What's Next?

After successful setup, you're ready to continue development:

1. **Review** the comprehensive TODO: `docs/TODO-OPTION-C-HYBRID-ELIXIR-GRAPHITI.md`
2. **Check** implementation status: `ELIXIR_IMPLEMENTATION_STATUS.md`
3. **Start** Phase 3: Graphiti Integration
   - See Phase 3 in the TODO document
   - Begin with `lib/semantic_graph/graphiti/client.ex`

## Project Structure

```
tui-story/
├── semantic_graph/           # Elixir/Phoenix app (Phase 1-2 ✅)
│   ├── lib/
│   │   ├── semantic_graph/
│   │   │   ├── resources/    # ✅ Vertex & Edge
│   │   │   ├── graph_api.ex  # ✅ Ash domain
│   │   │   └── application.ex # ✅ OTP app
│   │   └── semantic_graph_web/
│   ├── config/               # ✅ All configs
│   └── test/                 # ✅ Tests
├── graphiti_service/         # Python service (Phase 1 ✅)
│   ├── main.py              # ✅ FastAPI app
│   ├── graphiti_client.py   # ✅ Neo4j client
│   └── requirements.txt     # ✅ Dependencies
├── docker-compose.yml        # ✅ Orchestration
└── Makefile                  # ✅ Dev commands
```

## Getting Help

- **Documentation:** All `.md` files in project
- **Tests:** Examples in `semantic_graph/test/`
- **Original Implementation:** Zig code in `src/`
- **TODO Guide:** `docs/TODO-OPTION-C-HYBRID-ELIXIR-GRAPHITI.md`

Happy coding! 🚀
