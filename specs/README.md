# TLA+ Formal Specifications for Semantic Graph TUI

This directory contains formal specifications written in TLA+ (Temporal Logic of Actions Plus) for the Semantic Graph TUI application. These specifications provide rigorous mathematical models of the system's behavior, enabling verification of critical safety and liveness properties.

## Overview

TLA+ is a formal specification language used to design, model, and verify concurrent and distributed systems. These specifications capture the semantic and logical constraints of the application's core functionality.

## Specifications

### 1. SemanticGraphTUI.tla

**Purpose**: Main specification modeling the complete system behavior including UI state machine, graph operations, and analysis workflow.

**Key Components**:
- **UI State Machine**: Models transitions between `help`, `input`, `analyzing`, and `viewing_graph` modes
- **Graph Operations**: Vertex and edge management with validation
- **Analysis Workflow**: Incremental idea addition and relationship analysis
- **Validation Layer**: Input validation and error handling

**Verified Properties**:

**Safety Invariants**:
- `TypeInvariant`: All variables maintain correct types
- `UniqueVertexIds`: Vertex IDs are unique across the graph
- `SequentialVertexIds`: Vertex IDs are sequential starting from 0
- `ValidEdgeReferences`: Edges only reference existing vertices
- `NoSelfLoops`: No edge connects a vertex to itself
- `AnalysisConsistency`: Analysis mode implies analysis is in progress
- `InputLengthBound`: User input respects maximum length (1000 chars)
- `IdeasMatchVertices`: Idea count is consistent with vertex count
- `ValidCoordinates`: Vertex coordinates stay within layout bounds
- `DeterministicTransitions`: State machine transitions are deterministic

**Liveness Properties**:
- `EventuallyCompletesAnalysis`: Analysis always terminates (no infinite loops)
- `EventuallyProcessesInput`: Valid input eventually gets processed
- `EventuallyReturnsToHelp`: System can always return to help mode
- `AnalysisEventuallyTerminates`: Analysis with retries eventually succeeds or fails

**Usage**:
```bash
java -jar tla2tools.jar -config SemanticGraphTUI.cfg SemanticGraphTUI.tla
```

---

### 2. SemanticGraphConstraints.tla

**Purpose**: Detailed specification of the semantic graph data structure with structural and semantic constraints.

**Key Components**:
- **Relation Types**: All 9 semantic relationship types (contradictory, implicative, hierarchical, etc.)
- **Vertex Management**: Addition, retrieval, and layout positioning
- **Edge Management**: Relationship creation with certainty scores
- **Graph Topology**: Connectivity, density, and layout properties
- **Incremental Construction**: Adding ideas one at a time

**Verified Properties**:

**Structural Invariants**:
- `UniqueIds`: No duplicate vertex IDs
- `SequentialIds`: IDs form a sequence from 0 to n-1
- `NoIdGaps`: No missing IDs in the sequence
- `ValidEdges`: Edges reference existing vertices only
- `UniqueEdges`: At most one edge between any vertex pair (per direction)
- `BoundedVertices`: All vertices stay within layout bounds
- `SizeConsistency`: Vertex count equals next ID

**Semantic Invariants**:
- `SymmetricRelationConsistency`: Symmetric relations maintain semantic meaning
- `NoContradictoryRelations`: No conflicting relationship types between same vertices
- `CertaintyCoherence`: More specific relations have higher certainty
- `GroupSeparation`: Layout separates group 0 (left) from group 1 (right)

**Temporal Properties**:
- `StableVertexIds`: Once added, vertex IDs never change
- `MonotonicNextId`: Next ID counter only increases
- `EventualLayout`: Layout eventually calculated after adding vertices
- `Rebuildable`: Graph can be cleared and rebuilt

**Usage**:
```bash
java -jar tla2tools.jar -config SemanticGraphConstraints.cfg SemanticGraphConstraints.tla
```

---

### 3. LLMRetryLogic.tla

**Purpose**: Models the LLM API client's retry mechanism with exponential backoff and timeout handling.

**Key Components**:
- **Request Lifecycle**: Preparing, sending, waiting, parsing states
- **Retry Mechanism**: Up to 3 retries with exponential backoff
- **Error Handling**: Timeout, network, HTTP, and parse errors
- **Mock Fallback**: Deterministic mock mode when no API key is present
- **Backoff Strategy**: 1s → 2s → 4s → 8s (capped at 8s)

**Verified Properties**:

**Safety Invariants**:
- `TypeInvariant`: Request state and counters have correct types
- `RetryBound`: Retry count never exceeds maximum (3)
- `ValidBackoff`: Backoff times follow exponential pattern
- `StateConsistency`: Request states have consistent prerequisites
- `MockModeNoBackoff`: Mock mode never enters backoff (instant response)
- `RetryOnlyRetryableErrors`: Only retryable errors trigger retries

**Liveness Properties**:
- `EventuallyTerminates`: Every request completes or fails
- `MockModeImmediate`: Mock requests complete without retries
- `ExponentialBackoffProperty`: Backoff correctly applies exponential delays
- `MaxRetriesLeadsToFailure`: After max retries, request fails
- `EventuallyIdle`: System eventually returns to idle state
- `ImmediateFailureForNonRetryable`: Non-retryable errors fail immediately

**Usage**:
```bash
java -jar tla2tools.jar -config LLMRetryLogic.cfg LLMRetryLogic.tla
```

---

## Key Concepts

### Relation Types

The system models 9 semantic relationship types:

| Type | Symbol | Description | Symmetric? |
|------|--------|-------------|------------|
| `contradictory` | ⊥ | Ideas cannot both be true | Yes |
| `implicative` | → | One idea implies another | No |
| `hierarchical` | ⊆ | One is specific case of other | No |
| `evolutionary` | ⟿ | One developed from other | No |
| `analogous` | ≈ | Structural similarity | Yes |
| `synonymous` | ≡ | Same meaning | Yes |
| `antonymous` | ≠ | Opposite meaning | Yes |
| `part_whole` | ∈ | One is part of other | No |
| `causal` | ⇒ | One causes other | No |

### State Machine

```
[*] → help (Main Menu)
  ├─ 'e' → input → Enter → analyzing → viewing_graph
  ├─ 'v' → viewing_graph
  ├─ 'r' → reset
  └─ 'q' → [*] (Quit)
```

### Incremental Workflow

1. User enters first idea → Creates vertex (group 0)
2. User enters second idea → Creates vertex, analyzes relationships with first idea
3. User enters Nth idea → Creates vertex, analyzes relationships with all N-1 previous ideas
4. Graph grows incrementally with each new idea

### Layout Algorithm

- **Initial Positioning**: Group 0 left (x=25%), Group 1 right (x=75%)
- **Force-Directed**: 50 iterations of repulsive/attractive forces
- **Bounds Enforcement**: Vertices clamped to [0, width] × [0, height]

## Model Checking

### Prerequisites

1. Install TLA+ Toolbox: https://github.com/tlaplus/tlaplus/releases
2. Or use tla2tools.jar command-line tool

### Running Model Checker

```bash
# Check main specification
cd specs
java -jar tla2tools.jar -config SemanticGraphTUI.cfg SemanticGraphTUI.tla

# Check graph constraints
java -jar tla2tools.jar -config SemanticGraphConstraints.cfg SemanticGraphConstraints.tla

# Check retry logic
java -jar tla2tools.jar -config LLMRetryLogic.cfg LLMRetryLogic.tla
```

### Understanding Results

**No Errors Found**: All invariants hold, all properties verified ✅

**Invariant Violation**: Safety property broken - indicates bug in specification or implementation

**Deadlock**: System reached state with no valid transitions

**Temporal Property Violation**: Liveness property not satisfied - system may get stuck

### Performance Tuning

Model checking explores all possible states. For large state spaces:

1. **Reduce Constants**: Lower `MaxIdeas`, `MaxVertices` in `.cfg` files
2. **Add Constraints**: Limit state space with `CONSTRAINT` clauses
3. **Symmetry Reduction**: Enable if states are symmetric
4. **Bounded Model Checking**: Check only first N steps

Example:
```
CONSTRAINT Cardinality(vertices) <= 5  \* Limit to 5 vertices
```

## Mapping to Implementation

> **Note**: The implementation has been migrated from Zig to Elixir (Phases 1-4 complete). See `ELIXIR_IMPLEMENTATION_STATUS.md` for details.

### SemanticGraphTUI.tla → Elixir Modules

| Specification | Elixir Implementation | Original Zig Reference |
|---------------|----------------------|------------------------|
| `uiMode` | `semantic_graph/lib/semantic_graph/tui.ex::State.mode` | `ui.zig::UIMode` |
| `AddVertex()` | `semantic_graph/lib/semantic_graph/resources/vertex.ex::Vertex.add_idea/1` | `graph.zig::addVertex()` |
| `AddEdge()` | `semantic_graph/lib/semantic_graph/resources/edge.ex::Edge.add_relationship/1` | `graph.zig::addEdge()` |
| `ValidateInput` | `semantic_graph/lib/semantic_graph/resources/vertex.ex` (content validation) | `validation.zig::validateIdea()` |
| `StartAnalysis` | `semantic_graph/lib/semantic_graph/analysis/service.ex::Service.analyze_new_idea/1` | `ui.zig::analyzeNewIdea()` |
| `RetryAnalysis` | `semantic_graph/lib/semantic_graph/llm/client.ex` (Tesla middleware retry) | `llm.zig::analyzeRelationships()` |

### SemanticGraphConstraints.tla → Ash Resources

| Specification | Elixir Implementation | Original Zig Reference |
|---------------|----------------------|------------------------|
| `RelationType` | `semantic_graph/lib/semantic_graph/resources/edge.ex::Edge.relation_types/0` (9 types) | `graph.zig::RelationType` |
| `Vertex` | `semantic_graph/lib/semantic_graph/resources/vertex.ex::Vertex` (Ash resource) | `graph.zig::Vertex` |
| `Edge` | `semantic_graph/lib/semantic_graph/resources/edge.ex::Edge` (Ash resource) | `graph.zig::Edge` |
| `CalculateLayout` | Handled by TUI rendering (`semantic_graph/lib/semantic_graph/tui.ex`) | `graph.zig::calculateLayout()` |
| `GetVertex()` | `semantic_graph/lib/semantic_graph/resources/vertex.ex::Vertex.get_by_id!/1` | `graph.zig::getVertex()` |
| `EdgeExists()` | `semantic_graph/lib/semantic_graph/resources/edge.ex` (duplicate check in before_action) | `graph.zig::hasEdge()` |

### LLMRetryLogic.tla → LLM Client

| Specification | Elixir Implementation | Original Zig Reference |
|---------------|----------------------|------------------------|
| `requestState` | Tesla middleware (implicit state) | Implicit in `analyzeRelationships()` |
| `retryCount` | `semantic_graph/lib/semantic_graph/llm/client.ex` (Tesla.Middleware.Retry max_retries: 3) | `llm.zig::APIConfig.max_retries` |
| `CalculateBackoff()` | Tesla exponential backoff (max_delay: 8000ms) | Exponential backoff in retry loop |
| `mockMode` | `semantic_graph/lib/semantic_graph/llm/client.ex::Client.generate_mock_relationships/2` | `llm.zig::getMockRelationships()` |
| `TimeoutMs` | Tesla receive_timeout: 30_000ms | `llm.zig::APIConfig.timeout_ms` |

## Verification Checklist

### Safety Properties ✓

- [x] Type correctness: All variables have correct types
- [x] Uniqueness: Vertex IDs are unique
- [x] Referential integrity: Edges reference existing vertices
- [x] Bounds: Input lengths, coordinates, certainty values within bounds
- [x] State consistency: UI mode matches internal state
- [x] No deadlocks: System can always make progress
- [x] Retry limits: Retries never exceed maximum

### Liveness Properties ✓

- [x] Analysis termination: Analysis always completes or fails
- [x] Request completion: API requests eventually finish
- [x] Layout calculation: Layout eventually computed
- [x] Return to idle: System eventually returns to idle state
- [x] Mock mode: Mock requests complete immediately

### Semantic Properties ✓

- [x] Relation consistency: No contradictory relationship types
- [x] Certainty coherence: More specific relations have higher certainty
- [x] Group separation: Layout separates idea groups
- [x] Incremental consistency: Graph grows correctly with each idea
- [x] Edge uniqueness: Only one edge per vertex pair per direction

## Relationship to Architecture

These specifications formalize the design decisions captured in:

- **ADR-001**: libvaxis TUI → UI state machine
- **ADR-002**: Mock LLM fallback → `mockMode` in LLMRetryLogic
- **ADR-003**: Force-directed layout → `CalculateLayout` constraints
- **ADR-004**: Input validation → `ValidateInput` action
- **ADR-005**: Service layer → Analysis workflow actions

## Testing Correspondence

> **Note**: Test suite migrated to Elixir ExUnit framework. See `semantic_graph/test/` directory.

| TLA+ Property | Elixir Test Coverage | Original Zig Test |
|---------------|---------------------|-------------------|
| `UniqueVertexIds` | `semantic_graph/test/semantic_graph/resources/vertex_test.exs` | `tests/unit/graph_test.zig` |
| `ValidEdgeReferences` | `semantic_graph/test/semantic_graph/resources/edge_test.exs` | `tests/unit/graph_test.zig` |
| `EventuallyCompletesAnalysis` | `semantic_graph/test/semantic_graph/integration/workflow_test.exs::"incremental idea addition workflow"` | `tests/integration/workflow_test.zig` |
| `RetryBound` | `semantic_graph/test/semantic_graph/llm/client_test.exs` (Tesla retry middleware) | `tests/unit/llm_test.zig` |
| `InputLengthBound` | `semantic_graph/test/semantic_graph/integration/workflow_test.exs::"handles very long content validation"` | `tests/integration/workflow_test.zig` |
| `CertaintyCoherence` | `semantic_graph/test/semantic_graph/resources/edge_test.exs::"certainty-based deduplication"` | `tests/unit/graph_test.zig` |
| `GraphRebuildable` | `semantic_graph/test/semantic_graph/integration/workflow_test.exs::"graph can be reset and rebuilt"` | N/A |

## Future Work

### Potential Enhancements

1. **Concurrency**: Model multi-threaded graph operations
2. **Persistence**: Add disk I/O and crash recovery
3. **Networking**: Full HTTP request/response modeling
4. **User Input**: Model keyboard event sequences
5. **Layout Physics**: Detailed force-directed algorithm
6. **Batch Analysis**: Model analyzing multiple groups simultaneously

### Additional Properties

1. **Fairness**: All pending requests eventually get processed
2. **Bounded Response**: Analysis completes within time limit
3. **Resource Bounds**: Memory usage stays within limits
4. **Error Recovery**: System recovers from all error states

## References

- **TLA+ Homepage**: https://lamport.azurewebsites.net/tla/tla.html
- **Specifying Systems**: Leslie Lamport's TLA+ book
- **TLA+ Video Course**: https://lamport.azurewebsites.net/video/videos.html
- **TLA+ Toolbox**: https://github.com/tlaplus/tlaplus
- **TLA+ Community**: https://groups.google.com/g/tlaplus

## Contributing

When modifying the implementation:

1. Update corresponding TLA+ specifications
2. Re-run model checker to verify properties still hold
3. Add new invariants for new features
4. Document mapping in this README

## License

These specifications are part of the Semantic Graph TUI project.

---

**Last Updated**: 2025-11-20
**Author**: Claude (Anthropic)
**Specification Version**: 1.0.0
