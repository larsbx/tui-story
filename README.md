---
title: "Semantic Relationship Graph TUI"
description: "Terminal UI for analyzing semantic relationships between concepts using LLMs"
tags: [tui, llm, graph, semantic-analysis, elixir, phoenix, ash-framework, terminal, relationships]
last_updated: 2025-11-22
version: 0.4.0
---

# Semantic Relationship Graph TUI

![CI](https://github.com/larsbx/tui-story/workflows/CI/badge.svg)

A terminal user interface (TUI) application built with **Elixir**, **Phoenix**, **Ash Framework**, and **Ratatouille** that analyzes semantic relationships between concepts using LLMs and displays them as an interactive graph. Each new concept is automatically compared to all existing concepts, building a rich semantic network incrementally.

> **🎉 Migration Complete**: The application has been successfully migrated from Zig to Elixir (Phases 1-4 complete). The Elixir implementation provides better concurrency, fault tolerance, and maintainability while preserving all the original functionality. See [`ELIXIR_IMPLEMENTATION_STATUS.md`](./docs/project/ELIXIR_IMPLEMENTATION_STATUS.md) for details.

## Documentation

- **[MCP Server Mode](./docs/MCP_SERVER.md)** - Headless Model Context Protocol server documentation
- **[Changelog](./docs/project/CHANGELOG.md)** - Version history and release notes
- **[Examples](./docs/project/EXAMPLES.md)** - Usage examples across different domains
- **[Architecture](./docs/architecture/)** - Design decisions and diagrams
- **[Project Analysis](./docs/project/)** - Generated analysis and critique
  - [GEMINI.md](./docs/project/GEMINI.md) - AI-generated project overview
  - [CRITIQUE.md](./docs/project/CRITIQUE.md) - AI-generated project critique
  - [System Context Diagram](./docs/architecture/diagrams/system-context.md)
  - [Analysis Workflow](./docs/architecture/diagrams/analysis-workflow.md)
  - [Architecture Decision Records (ADRs)](./docs/architecture/README.md)
- **[Implementation Summary](./docs/project/IMPLEMENTATION_SUMMARY.md)** - Recent architectural improvements
- **[Formal Verification](./specs/)** - TLA+ specifications and proofs
  - [Executive Summary](./docs/EXECUTIVE_SUMMARY.md)
- **[Reference & Manifestos](./docs/reference/manifestos/)** - Philosophy and methodology documents
  - [Formal Verification Manifesto](./docs/reference/manifestos/FORMAL_VERIFICATION_MANIFESTO.md)
  - [Data & Analytics Manifesto](./docs/reference/manifestos/DATA_ANALYTICS_MANIFESTO.md) - 18 foundational principles for data engineering excellence
  - [Vibe Coding Manifesto](./docs/reference/manifestos/VIBE_CODING_MANIFESTO.md) - Intuition-driven development methodology

## Features

- **MCP Server Mode**: Run as a headless Model Context Protocol server for integration with Claude and other LLM applications
  - **Stdio mode**: Single-client MCP over stdin/stdout
  - **HTTP mode**: Multi-client concurrent MCP with thread-safe graph access
- **Incremental Concept Entry**: Enter concepts one at a time, each automatically compared to all existing concepts
- **Dense Semantic Network**: Each new concept creates relationships with all previous concepts
- **LLM-Powered Analysis**: Uses large language models to identify semantic relationships
- **Graph Visualization**: Displays relationships as vertices (concepts) and edges (relationships)
- **Multiple Relationships**: Nodes can have multiple different relationship types between them
- **Intelligent Deduplication**: Prevents duplicate relationships and updates based on certainty
- **Multi-Agent Support**: Multiple agents can collaborate on the same semantic graph
- **9 Relationship Types**:
  - **CONTRADICTORY** (⊥): Propositions that cannot both be true
  - **IMPLICATIVE** (→): Propositions where one logically implies another
  - **HIERARCHICAL** (⊆): Concepts where one is a specific case of another
  - **EVOLUTIONARY** (⟿): Concepts where one developed from another
  - **ANALOGOUS** (≈): Concepts that share structural similarity
  - **SYNONYMOUS** (≡): Terms that mean the same thing
  - **ANTONYMOUS** (≠): Terms that are opposites
  - **PART_WHOLE** (∈): Entities where one is part of another
  - **CAUSAL** (⇒): Events where one causes another

- **Interactive Navigation**: Browse relationships with arrow keys
- **Certainty Scores**: Each relationship includes a confidence level

## Requirements

- **Elixir** 1.14+ and **Erlang/OTP** 25+
- **Docker** and **Docker Compose** (for Neo4j and Graphiti service)
- Terminal with Unicode support
- (Optional) API key for LLM provider (Anthropic, OpenAI, or custom)

## Installation

### Quick Start with Docker

```bash
# 1. Clone the repository
git clone <repository-url>
cd tui-story

# 2. Set up environment
make setup
# Edit .env with your API keys

# 3. Start services (Neo4j + Graphiti)
make start

# 4. Install Elixir dependencies
cd semantic_graph
mix deps.get
mix compile

# 5. Run the TUI application
iex -S mix
```

### Manual Installation

1. **Install Elixir and Erlang**:
```bash
# Using asdf (recommended)
asdf install elixir 1.16.0
asdf install erlang 26.2

# Or use your package manager
# Ubuntu/Debian: apt install elixir erlang
# macOS: brew install elixir
```

2. **Install dependencies**:
```bash
cd semantic_graph
mix deps.get
mix compile
```

3. **Start the application**:
```bash
# With TUI
iex -S mix

# Or run tests
mix test
```

## Testing

This project includes comprehensive unit and integration tests using **ExUnit** to ensure code quality and prevent regressions.

### Running Tests

```bash
# Navigate to the Elixir project
cd semantic_graph

# Run all tests
mix test

# Run tests with detailed output
mix test --trace

# Run specific test file
mix test test/semantic_graph/resources/vertex_test.exs

# Run tests with coverage
mix test --cover
```

### Test Structure

```
semantic_graph/test/
├── test_helper.exs                      # Test configuration
└── semantic_graph/
    ├── resources/                       # Resource tests
    │   ├── vertex_test.exs              # Vertex (concept) tests
    │   └── edge_test.exs                # Edge (relationship) tests
    ├── llm/                             # LLM client tests
    │   └── client_test.exs              # API client and mock tests
    ├── analysis/                        # Analysis service tests
    │   └── service_test.exs             # Orchestration logic tests
    ├── graphiti/                        # Graphiti integration tests
    │   ├── client_test.exs              # HTTP client tests
    │   └── integration_test.exs         # GenServer integration tests
    └── integration/                     # End-to-end tests
        └── workflow_test.exs            # Incremental idea workflow tests
```

### Test Coverage

The Elixir test suite includes:

- **Vertex Resource** (8+ tests):
  - Content validation (length, emptiness, whitespace)
  - Group assignment
  - Position management
  - CRUD operations

- **Edge Resource** (12+ tests):
  - All 9 relationship types
  - Certainty validation (0.0-1.0 range)
  - Self-loop prevention
  - Certainty-based deduplication
  - Symbol mapping

- **LLM Client** (5+ tests):
  - Mock relationship generation
  - Provider configuration (Anthropic, OpenAI, custom)
  - Retry logic with exponential backoff

- **Analysis Service** (4+ tests):
  - First idea creation
  - Multi-idea relationship analysis
  - Async task execution

- **Graphiti Integration** (6+ tests):
  - Health check scenarios
  - Concept syncing
  - Graceful degradation

- **Integration Workflows** (15+ tests):
  - Incremental idea addition
  - Validation error handling
  - Graph state consistency
  - Async analysis

**Total: 50+ tests**

### Memory Safety & Fault Tolerance

Elixir provides built-in memory safety and fault tolerance through:

- **BEAM VM**: Garbage collection and process isolation
- **OTP Supervision Trees**: Automatic process restart on failure
- **Immutability**: No memory leaks from shared mutable state
- **Process Isolation**: Crashes don't affect other parts of the system

### Continuous Integration

Tests run automatically on every push via GitHub Actions:
- ✅ All tests must pass
- ✅ Code formatting must be correct (`mix format --check-formatted`)
- ✅ Builds verified on Ubuntu

See `.github/workflows/ci.yml` for CI configuration.

### Writing Tests

When adding new features, include tests using ExUnit:

```elixir
defmodule SemanticGraph.YourModuleTest do
  use ExUnit.Case, async: true

  alias SemanticGraph.YourModule

  setup do
    # Setup code here
    :ok
  end

  describe "your_function/1" do
    test "does what it should do" do
      result = YourModule.your_function(input)
      assert result == expected
    end
  end
end
```

## Usage

### Run the TUI application:
```bash
cd semantic_graph
iex -S mix
```

The Ratatouille TUI will start automatically. Use the keyboard shortcuts listed in the help screen to interact with the application.

### Run as MCP server (headless mode):

> **Note**: MCP server mode is planned for Phase 5. The Elixir/Phoenix backend is ready for MCP integration.

For complete MCP server documentation, see **[MCP Server Mode](./docs/MCP_SERVER.md)**.

### Run Graphiti Services (Optional):

For enhanced semantic analysis with temporal knowledge graphs:

```bash
# Start Neo4j and Graphiti service
make start

# Check service health
make health

# View logs
make logs
```

### LLM Provider Configuration

The application supports multiple LLM providers. Without configuration, it uses mock data for demonstration.

#### Anthropic (default)
```bash
export ANTHROPIC_API_KEY="your-api-key-here"
zig build run
```

#### OpenAI
```bash
export LLM_PROVIDER="openai"
export OPENAI_API_KEY="your-api-key-here"
zig build run
```

#### Custom API (e.g., local LLM, Ollama, etc.)
```bash
export LLM_PROVIDER="custom"
export LLM_API_KEY="your-api-key-here"  # Optional
export LLM_API_ENDPOINT="http://localhost:8000/v1/chat/completions"
export LLM_MODEL="llama3"
export LLM_AUTH_HEADER="Authorization"  # Optional, defaults to "Authorization"
export LLM_AUTH_PREFIX="Bearer "  # Optional, defaults to "Bearer "
zig build run
```

#### Advanced Configuration

You can override any provider's default settings:

```bash
# Use Anthropic with a different model
export ANTHROPIC_API_KEY="your-key"
export LLM_MODEL="claude-3-opus-20240229"

# Use OpenAI with a custom endpoint (e.g., Azure)
export LLM_PROVIDER="openai"
export OPENAI_API_KEY="your-key"
export LLM_API_ENDPOINT="https://your-resource.openai.azure.com/openai/deployments/your-deployment/chat/completions?api-version=2024-02-15-preview"
export LLM_MODEL="gpt-4"
```

**Environment Variables:**
- `LLM_PROVIDER` - Provider type: `anthropic` (default), `openai`, or `custom`
- `LLM_MODEL` - Model name to use (provider-specific defaults)
- `LLM_API_ENDPOINT` - API endpoint URL (provider-specific defaults)
- `LLM_API_KEY` - API key for custom providers
- `LLM_AUTH_HEADER` - Authentication header name for custom providers (default: `Authorization`)
- `LLM_AUTH_PREFIX` - Auth value prefix for custom providers (default: `Bearer `)
- `ANTHROPIC_API_KEY` - API key for Anthropic (when provider is anthropic)
- `OPENAI_API_KEY` - API key for OpenAI (when provider is openai)

### Controls

**Main Menu:**
- `e` - Enter a new concept (automatically analyzes relationships with existing concepts)
- `v` - View the relationship graph
- `r` - Reset all data
- `q` - Quit application

**Input Mode:**
- Type your concept and press `Enter` to add it (triggers automatic analysis)
- `Esc` - Return to main menu

**Graph View:**
- `↑↓` - Navigate between relationships
- `h` or `Esc` - Return to main menu
- `q` - Quit application

## Example Usage

> **For more examples, see [EXAMPLES.md](./docs/project/EXAMPLES.md)** - Political systems, programming paradigms, scientific theories, machine learning, and economic systems.

The application uses an **incremental workflow** where each new concept is automatically analyzed against all existing concepts:

1. Press `e` to enter your first concept:
   - "Democracy"

2. Press `e` to enter your second concept:
   - "Authoritarianism"
   - The LLM automatically identifies: Democracy ⊥ Authoritarianism (CONTRADICTORY)

3. Press `e` to enter your third concept:
   - "Representative government"
   - The LLM compares it to both previous concepts:
     - Representative government ⊆ Democracy (HIERARCHICAL)
     - Representative government ⊥ Authoritarianism (CONTRADICTORY)

4. Continue adding concepts - each is automatically compared to all previous concepts

5. Press `v` at any time to view the graph visualization

**Benefits of Incremental Approach:**
- Dense connectivity: Each concept relates to all previous concepts
- Real-time graph evolution: See patterns emerge as you add concepts
- Incremental knowledge integration: Build understanding step by step
- Pattern discovery: Identify central concepts, clusters, and bridges

See [Analysis Workflow diagram](./docs/architecture/diagrams/analysis-workflow.md) for detailed process flow.

## Architecture

> **For detailed architecture documentation, see:**
> - [System Context Diagram](./docs/architecture/diagrams/system-context.md) - High-level system overview
> - [Analysis Workflow](./docs/architecture/diagrams/analysis-workflow.md) - End-to-end process flow
> - [Module Dependencies](./docs/architecture/diagrams/module-dependencies.md) - Code organization
> - [UI State Machine](./docs/architecture/diagrams/ui-state-machine.md) - TUI navigation flow
> - [Graph Layout Algorithm](./docs/architecture/diagrams/graph-layout.md) - Force-directed positioning
> - [Architecture Decision Records](./docs/architecture/README.md) - Design decisions and rationale

### File Structure
```
tui-story/
├── semantic_graph/                      # Elixir/Phoenix application
│   ├── lib/
│   │   ├── semantic_graph/
│   │   │   ├── application.ex           # OTP supervision tree
│   │   │   ├── resources/
│   │   │   │   ├── vertex.ex            # Vertex (concept) Ash resource
│   │   │   │   └── edge.ex              # Edge (relationship) Ash resource
│   │   │   ├── graph_api.ex             # Ash domain & convenience API
│   │   │   ├── llm/
│   │   │   │   └── client.ex            # LLM API client (Tesla, retry logic)
│   │   │   ├── analysis/
│   │   │   │   └── service.ex           # Analysis orchestration
│   │   │   ├── graphiti/
│   │   │   │   ├── client.ex            # Graphiti HTTP client
│   │   │   │   └── integration.ex       # Graphiti GenServer integration
│   │   │   └── tui.ex                   # Ratatouille TUI application
│   │   └── semantic_graph_web/
│   │       ├── endpoint.ex              # Phoenix HTTP endpoint
│   │       ├── router.ex                # HTTP routes
│   │       ├── telemetry.ex             # Metrics & observability
│   │       └── controllers/
│   │           ├── health_controller.ex # Health check endpoint
│   │           └── (MCP in Phase 5)     # MCP JSON-RPC controller
│   ├── config/                          # Environment configuration
│   ├── test/                            # ExUnit test suite
│   └── mix.exs                          # Project dependencies
├── graphiti_service/                    # Python FastAPI service
│   ├── main.py                          # FastAPI application
│   ├── graphiti_client.py               # Neo4j/Graphiti client
│   └── models.py                        # Pydantic models
├── docs/architecture/                   # Architecture documentation & ADRs
├── specs/                               # TLA+ formal specifications
├── docker-compose.yml                   # Service orchestration
└── Makefile                             # Convenience commands
```

See [ADR-005](./docs/architecture/ADR-005-service-layer-extraction.md) for service layer rationale.
See [ADR-006](./docs/architecture/ADR-006-graphiti-knowledge-graph-integration.md) for Graphiti integration.
See [ELIXIR_IMPLEMENTATION_STATUS.md](./docs/project/ELIXIR_IMPLEMENTATION_STATUS.md) for migration details.

### Data Structures

**Vertex (Node):**
- Represents a concept
- Has position (x, y) for layout
- Contains the concept text/content

**Edge (Relationship):**
- Connects two vertices
- Has a relationship type (see [9 relationship types](#features))
- Includes certainty score (0.0 - 1.0)
- Contains description/justification

**SemanticGraph:**
- Manages vertices and edges
- Implements [force-directed layout algorithm](./docs/architecture/diagrams/graph-layout.md)
- Supports multiple relationship types between same nodes
- Prevents duplicate relationships with certainty-based updates

See [ADR-003](./docs/architecture/ADR-003-force-directed-graph-layout.md) for layout algorithm choice.

## Formal Verification

This project includes comprehensive formal specifications written in **TLA+ (Temporal Logic of Actions Plus)** to rigorously verify system behavior and properties.

### Specifications

Located in the `specs/` directory:

- **[SemanticGraphTUI.tla](./specs/SemanticGraphTUI.tla)**: Main system specification
  - UI state machine with mode transitions
  - Graph operations and validation
  - Analysis workflow and incremental idea addition
  - 10 safety invariants + 4 liveness properties verified

- **[SemanticGraphConstraints.tla](./specs/SemanticGraphConstraints.tla)**: Graph data structure
  - Structural invariants (unique IDs, valid edges, no gaps)
  - Semantic invariants (relationship consistency, certainty coherence)
  - Temporal properties (stable IDs, monotonic counters)
  - 7 structural + 4 semantic + 4 temporal properties verified

- **[LLMRetryLogic.tla](./specs/LLMRetryLogic.tla)**: Retry mechanism
  - Exponential backoff strategy (1s → 2s → 4s → 8s)
  - Request lifecycle states and error handling
  - Mock mode behavior verification
  - 6 safety + 6 liveness properties verified

- **[ValidationLayer.tla](./specs/ValidationLayer.tla)**: Input validation and security boundaries

### Verified Properties

**Safety Properties (things that must never happen):**
- ✅ Type correctness across all variables
- ✅ Unique vertex IDs throughout graph lifetime
- ✅ Edges only reference existing vertices
- ✅ No self-loops or invalid states
- ✅ Bounded input lengths and retry counts
- ✅ No contradictory relationship types between same vertices

**Liveness Properties (things that must eventually happen):**
- ✅ Analysis always terminates (no infinite loops)
- ✅ API requests eventually complete or fail
- ✅ Layout calculations eventually finish
- ✅ System can always return to idle state

### Model Checking

```bash
# Install TLA+ tools
cd specs

# Verify main system specification
java -jar tla2tools.jar -config SemanticGraphTUI.cfg SemanticGraphTUI.tla

# Verify graph constraints
java -jar tla2tools.jar -config SemanticGraphConstraints.cfg SemanticGraphConstraints.tla

# Verify retry logic
java -jar tla2tools.jar -config LLMRetryLogic.cfg LLMRetryLogic.tla
```

### Documentation

- **[Formal Verification Manifesto](./docs/FORMAL_VERIFICATION_MANIFESTO.md)**: 16 foundational principles for formal methods
- **[Executive Summary](./docs/EXECUTIVE_SUMMARY.md)**: For engineering leadership and decision-makers
- **[specs/README.md](./specs/README.md)**: Comprehensive guide to all specifications
- **[specs/SEMANTIC_ANALYSIS.md](./specs/SEMANTIC_ANALYSIS.md)**: Detailed invariant and property analysis

### Benefits

- **Correctness Guarantees**: Mathematical proof that critical properties hold
- **Bug Prevention**: Catches design errors before implementation
- **Documentation**: Specifications serve as precise, unambiguous documentation
- **Refactoring Confidence**: Properties remain verified across code changes
- **Test Coverage**: Formal specs complement unit and integration tests

See [specs/README.md](./specs/README.md) for mapping between specifications and implementation code.

## Extending the Application

### Adding New Relationship Types

Edit `semantic_graph/lib/semantic_graph/resources/edge.ex` and add to the relationship types:

```elixir
defmodule SemanticGraph.Resources.Edge do
  # ...existing code...

  @relation_types [
    # ... existing types ...
    :your_new_type
  ]

  # Add symbol mapping
  def relation_symbol(:your_new_type), do: "★"
  def relation_symbol(type), do: "?" # fallback

  # Update validation if needed
end
```

### Implementing Custom LLM Providers

Edit `semantic_graph/lib/semantic_graph/llm/client.ex` to add new providers:

```elixir
defmodule SemanticGraph.LLM.Client do
  # Add your provider configuration
  defp get_config do
    provider = System.get_env("LLM_PROVIDER", "your_provider")

    case provider do
      "your_provider" ->
        %{
          base_url: "https://your-api.example.com",
          model: "your-model",
          api_key: System.get_env("YOUR_API_KEY")
        }
      # ... existing providers ...
    end
  end

  # Implement provider-specific request formatting
  defp format_request(prompt, config) do
    # Your custom request format
  end
end
```

### Customizing TUI Appearance

Edit `semantic_graph/lib/semantic_graph/tui.ex` to customize the interface:

```elixir
defmodule SemanticGraph.TUI do
  # Customize colors, layouts, animations
  # Adjust rendering functions
  # Add new keyboard shortcuts
end
```

### Adding New Ash Actions

To add custom operations on Vertex or Edge resources:

```elixir
# In semantic_graph/lib/semantic_graph/resources/vertex.ex

actions do
  # ... existing actions ...

  update :your_custom_action do
    accept [:field1, :field2]

    change fn changeset, _context ->
      # Your custom logic here
      changeset
    end
  end
end

# Create code interface
code_interface do
  define :your_custom_action, args: [:field1, :field2]
end
```

See [Ash Framework documentation](https://ash-hq.org) for advanced patterns.

## License

MIT

## Contributing

Contributions welcome! Please feel free to submit issues or pull requests.

## Credits

Built with:
- [Elixir](https://elixir-lang.org/) - Functional programming language
- [Phoenix Framework](https://www.phoenixframework.org/) - Web framework
- [Ash Framework](https://ash-hq.org/) - Declarative resource framework
- [Ratatouille](https://github.com/ndreynolds/ratatouille) - Terminal UI library
- [Tesla](https://github.com/elixir-tesla/tesla) - HTTP client
- [Graphiti](https://github.com/getzep/graphiti) - Temporal knowledge graph (Python)
- [Neo4j](https://neo4j.com/) - Graph database

Originally prototyped with:
- [Zig](https://ziglang.org/) - Systems programming language (migrated to Elixir in v0.4.0)
