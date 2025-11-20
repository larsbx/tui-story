---
title: "Semantic Relationship Graph TUI"
description: "Terminal UI for analyzing semantic relationships between ideas using LLMs"
tags: [tui, llm, graph, semantic-analysis, zig, terminal, relationships]
last_updated: 2025-11-20
version: 0.3.0
---

# Semantic Relationship Graph TUI

![CI](https://github.com/larsbx/tui-story/workflows/CI/badge.svg)

A terminal user interface (TUI) application built with Zig and libvaxis that analyzes semantic relationships between ideas using LLMs and displays them as an interactive graph. Each new idea is automatically compared to all existing ideas, building a rich semantic network incrementally.

## Documentation

- **[Changelog](./CHANGELOG.md)** - Version history and release notes
- **[Examples](./EXAMPLES.md)** - Usage examples across different domains
- **[Architecture](./docs/architecture/)** - Design decisions and diagrams
  - [System Context Diagram](./docs/architecture/diagrams/system-context.md)
  - [Analysis Workflow](./docs/architecture/diagrams/analysis-workflow.md)
  - [Architecture Decision Records (ADRs)](./docs/architecture/README.md)
- **[Implementation Summary](./IMPLEMENTATION_SUMMARY.md)** - Recent architectural improvements
- **[Formal Verification](./specs/)** - TLA+ specifications and proofs
  - [Formal Verification Manifesto](./docs/FORMAL_VERIFICATION_MANIFESTO.md)
  - [Executive Summary](./docs/EXECUTIVE_SUMMARY.md)

## Features

- **Incremental Idea Entry**: Enter ideas one at a time, each automatically compared to all existing ideas
- **Dense Semantic Network**: Each new idea creates relationships with all previous ideas
- **LLM-Powered Analysis**: Uses large language models to identify semantic relationships
- **Graph Visualization**: Displays relationships as vertices (ideas) and edges (relationships)
- **Multiple Relationships**: Nodes can have multiple different relationship types between them
- **Intelligent Deduplication**: Prevents duplicate relationships and updates based on certainty
- **9 Relationship Types**:
  - **CONTRADICTORY** (⊥): Ideas that cannot both be true
  - **IMPLICATIVE** (→): One idea logically implies another
  - **HIERARCHICAL** (⊆): One idea is a specific case of another
  - **EVOLUTIONARY** (⟿): One idea developed from another
  - **ANALOGOUS** (≈): Ideas share structural similarity
  - **SYNONYMOUS** (≡): Ideas mean the same thing
  - **ANTONYMOUS** (≠): Ideas are opposites
  - **PART_WHOLE** (∈): One idea is part of another
  - **CAUSAL** (⇒): One idea causes another

- **Interactive Navigation**: Browse relationships with arrow keys
- **Certainty Scores**: Each relationship includes a confidence level

## Requirements

- Zig 0.13.0 or later
- Terminal with Unicode support
- (Optional) Anthropic API key for real LLM analysis

## Installation

1. Install Zig:
```bash
# Download Zig 0.13.0
wget https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz
tar -xf zig-linux-x86_64-0.13.0.tar.xz
export PATH="$PWD/zig-linux-x86_64-0.13.0:$PATH"
```

2. Clone and build:
```bash
git clone <repository-url>
cd tui-story
zig build
```

## Testing

This project includes comprehensive unit tests to ensure code quality and prevent regressions.

### Running Tests

```bash
# Run all tests
zig build test

# Run tests with detailed output
zig build test --summary all

# Run tests with verbose output (useful for debugging)
zig build test --summary all --verbose
```

### Test Structure

```
tests/
├── unit/              # Unit tests for individual modules
│   ├── graph_test.zig # Graph data structure tests
│   ├── llm_test.zig   # LLM client tests
│   └── ui_test.zig    # UI state management tests
├── integration/       # Integration tests (future)
└── fixtures/          # Test data and fixtures (future)
```

### Test Coverage

The test suite includes:

- **Graph Module** (21 tests):
  - RelationType conversions and properties
  - Vertex and edge management
  - Memory safety validation
  - Layout algorithm correctness
  - Boundary condition handling

- **LLM Module** (16 tests):
  - Client initialization
  - Prompt building and formatting
  - Mock relationship generation
  - Memory safety for relationships
  - API fallback behavior

- **UI Module** (15 tests):
  - State initialization
  - Mode transitions
  - Idea list management
  - Input buffer handling
  - Memory safety for UI state

**Total: 52+ unit tests**

### Memory Safety

All tests use Zig's `GeneralPurposeAllocator` with leak detection to ensure proper memory management:

```zig
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
defer {
    const leaked = gpa.deinit();
    try testing.expect(leaked == .ok); // Fail if memory leaked
}
```

### Continuous Integration

Tests run automatically on every push via GitHub Actions:
- ✅ All tests must pass
- ✅ Code formatting must be correct (`zig fmt --check`)
- ✅ Builds verified on Ubuntu and macOS

See `.github/workflows/ci.yml` for CI configuration.

### Writing Tests

When adding new features, include tests:

```zig
const std = @import("std");
const testing = std.testing;
const your_module = @import("../../src/your_module.zig");

test "your test description" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        try testing.expect(leaked == .ok);
    }
    const allocator = gpa.allocator();

    // Your test code here
    try testing.expect(condition);
}
```

## Usage

### Run the application:
```bash
zig build run
```

### Optional: Set API key for real LLM analysis
```bash
export ANTHROPIC_API_KEY="your-api-key-here"
zig build run
```

Without an API key, the application uses mock data for demonstration.

### Controls

**Main Menu:**
- `e` - Enter a new idea (automatically analyzes relationships with existing ideas)
- `v` - View the relationship graph
- `r` - Reset all data
- `q` - Quit application

**Input Mode:**
- Type your idea and press `Enter` to add it (triggers automatic analysis)
- `Esc` - Return to main menu

**Graph View:**
- `↑↓` - Navigate between relationships
- `h` or `Esc` - Return to main menu
- `q` - Quit application

## Example Usage

> **For more examples, see [EXAMPLES.md](./EXAMPLES.md)** - Political systems, programming paradigms, scientific theories, machine learning, and economic systems.

The application uses an **incremental workflow** where each new idea is automatically analyzed against all existing ideas:

1. Press `e` to enter your first idea:
   - "Democracy"

2. Press `e` to enter your second idea:
   - "Authoritarianism"
   - The LLM automatically identifies: Democracy ⊥ Authoritarianism (CONTRADICTORY)

3. Press `e` to enter your third idea:
   - "Representative government"
   - The LLM compares it to both previous ideas:
     - Representative government ⊆ Democracy (HIERARCHICAL)
     - Representative government ⊥ Authoritarianism (CONTRADICTORY)

4. Continue adding ideas - each is automatically compared to all previous ideas

5. Press `v` at any time to view the graph visualization

**Benefits of Incremental Approach:**
- Dense connectivity: Each idea relates to all previous ideas
- Real-time graph evolution: See patterns emerge as you add ideas
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
├── build.zig                    # Build configuration
├── build.zig.zon                # Dependencies (libvaxis)
├── docs/architecture/           # Architecture documentation & ADRs
└── src/
    ├── main.zig                 # Application entry point and event loop
    ├── graph.zig                # Graph data structures (vertices, edges)
    ├── llm.zig                  # LLM API client (with retry/timeout)
    ├── ui.zig                   # User interface rendering
    ├── analysis_service.zig     # Business logic orchestration
    └── validation.zig           # Input validation layer
```

See [ADR-005](./docs/architecture/ADR-005-service-layer-extraction.md) for service layer rationale.

### Data Structures

**Vertex (Node):**
- Represents an idea/concept
- Has position (x, y) for layout
- Contains the idea text/content

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

Edit `src/graph.zig` and add to the `RelationType` enum:

```zig
pub const RelationType = enum {
    // ... existing types ...
    your_new_type,

    pub fn toString(self: RelationType) []const u8 {
        return switch (self) {
            // ... existing cases ...
            .your_new_type => "YOUR_NEW_TYPE",
        };
    }

    pub fn getSymbol(self: RelationType) []const u8 {
        return switch (self) {
            // ... existing cases ...
            .your_new_type => "★",
        };
    }
};
```

### Implementing Real LLM Integration

Edit `src/llm.zig` and implement the `callAPI` and `parseResponse` functions:

```zig
fn callAPI(self: *LLMClient, prompt: []const u8) ![]const u8 {
    // Use std.http.Client to make API calls
    // Format request according to your LLM provider's API
    // Return the JSON response
}

fn parseResponse(self: *LLMClient, response: []const u8) ![]Relationship {
    // Parse JSON response
    // Extract relationships
    // Return array of Relationship structs
}
```

### Customizing Graph Layout

Edit the `calculateLayout` function in `src/graph.zig` to adjust:
- Initial positioning
- Force-directed algorithm parameters
- Group separation distance

See [Graph Layout Algorithm diagram](./docs/architecture/diagrams/graph-layout.md) for implementation details and [ADR-003](./docs/architecture/ADR-003-force-directed-graph-layout.md) for algorithm selection rationale.

## License

MIT

## Contributing

Contributions welcome! Please feel free to submit issues or pull requests.

## Credits

Built with:
- [Zig](https://ziglang.org/) - Programming language
- [libvaxis](https://github.com/rockorager/libvaxis) - Terminal UI library
