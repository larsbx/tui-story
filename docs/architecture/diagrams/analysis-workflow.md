# Analysis Workflow Diagram

**Last Updated**: 2025-11-20
**Type**: Sequence Diagram
**Purpose**: Shows end-to-end flow of semantic relationship analysis

## Diagram

```mermaid
sequenceDiagram
    actor User
    participant UI as UI Layer<br/>(ui.zig)
    participant Val as Validation<br/>(validation.zig)
    participant Svc as Analysis Service<br/>(analysis_service.zig)
    participant Graph as Graph Engine<br/>(graph.zig)
    participant LLM as LLM Client<br/>(llm.zig)
    participant API as LLM API<br/>(Anthropic)

    %% Input Phase
    Note over User,UI: Phase 1: Idea Collection
    User->>UI: Press '1' (Add to Group A)
    activate UI
    UI->>UI: Enter input mode
    User->>UI: Type idea + Enter
    UI->>Val: validateIdea(input)
    activate Val
    alt Input valid
        Val-->>UI: OK
        UI->>UI: Add to group1_ideas
        UI->>User: Show success
    else Input invalid
        Val-->>UI: Error (empty/too long/invalid UTF-8)
        UI->>User: Display error message
    end
    deactivate Val
    deactivate UI

    User->>UI: Press '2' (Add to Group B)
    Note over UI: (Repeat validation for Group B)

    %% Analysis Phase
    Note over User,API: Phase 2: Semantic Analysis
    User->>UI: Press 'a' (Analyze)
    activate UI
    UI->>Svc: analyzeGroups(group1, group2, graph, llm)
    activate Svc

    %% Build Graph
    Svc->>Graph: clear()
    activate Graph
    Graph-->>Svc: OK
    deactivate Graph

    loop For each idea in Group A
        Svc->>Graph: addVertex(idea, group=0)
        activate Graph
        Graph->>Val: validateVertexContent(idea)
        Val-->>Graph: OK
        Graph-->>Svc: vertex_id
        deactivate Graph
    end

    loop For each idea in Group B
        Svc->>Graph: addVertex(idea, group=1)
        Note over Graph: (Same validation)
    end

    %% LLM Analysis
    Svc->>LLM: analyzeRelationships(group1, group2)
    activate LLM
    LLM->>LLM: buildPrompt()

    alt API Key present
        LLM->>API: POST /v1/messages
        activate API
        API-->>LLM: Relationships JSON
        deactivate API
        LLM->>LLM: parseResponse()
    else No API Key
        LLM->>LLM: generateMockRelationships()
        Note over LLM: Development fallback
    end

    LLM-->>Svc: []Relationship
    deactivate LLM

    %% Build Edges
    loop For each relationship
        Svc->>Graph: addEdge(from, to, type, certainty)
        activate Graph
        Graph->>Graph: Validate vertices exist
        Graph-->>Svc: edge_id
        deactivate Graph
    end

    Svc->>Graph: calculateLayout()
    activate Graph
    Graph->>Graph: Force-directed algorithm
    Note over Graph: Iterative layout<br/>with group separation
    Graph-->>Svc: Layout complete
    deactivate Graph

    Svc-->>UI: Analysis complete
    deactivate Svc
    UI->>User: Show "Analysis complete"
    deactivate UI

    %% Visualization Phase
    Note over User,Graph: Phase 3: Graph Visualization
    User->>UI: Press 'v' (View graph)
    activate UI
    UI->>UI: Enter graph_view mode
    UI->>Graph: getVertices(), getEdges()
    activate Graph
    Graph-->>UI: Graph data with layout
    deactivate Graph
    UI->>UI: Render graph
    UI->>User: Display visualization

    User->>UI: Arrow keys (Navigate)
    UI->>UI: Update selected relationship
    UI->>User: Highlight relationship + details
    deactivate UI
```

## Workflow Phases

### Phase 1: Idea Collection
**Duration**: 1-5 minutes
**User Actions**: Enter ideas for both groups
**System**: Validates input at boundary

**Validation checks**:
- Not empty
- ≤ 1000 characters
- Valid UTF-8 encoding
- Whitespace trimmed

See [ADR-004: Input Validation Layer](../ADR-004-input-validation-layer.md)

### Phase 2: Semantic Analysis
**Duration**: 5-30 seconds (LLM dependent)
**User Actions**: Trigger analysis
**System**: Multi-step orchestration

**Steps**:
1. **Clear graph**: Remove previous analysis
2. **Build vertices**: Add all ideas as nodes
3. **LLM analysis**: Identify relationships (with retry/timeout)
4. **Build edges**: Connect related ideas
5. **Calculate layout**: Position nodes visually

See [ADR-005: Service Layer Extraction](../ADR-005-service-layer-extraction.md)

### Phase 3: Graph Visualization
**Duration**: Until user exits
**User Actions**: Navigate relationships
**System**: Interactive rendering

**Features**:
- Arrow key navigation
- Relationship highlighting
- Certainty scores displayed
- Symbol legend

See [ADR-003: Force-Directed Graph Layout](../ADR-003-force-directed-graph-layout.md)

## Error Handling

```mermaid
graph TD
    Start[User Action]
    Val{Validation}
    Retry{LLM Retry<br/>< 3 attempts?}
    Success[Success]
    ValError[Show Validation Error]
    LLMError[Show LLM Error]

    Start --> Val
    Val -->|Invalid| ValError
    Val -->|Valid| Process[Process Request]
    Process --> LLMCall{LLM Required?}
    LLMCall -->|Yes| LLM[Call LLM API]
    LLMCall -->|No| Success
    LLM -->|Success| Success
    LLM -->|Failure| Retry
    Retry -->|Yes| Wait[Exponential Backoff]
    Wait --> LLM
    Retry -->|No| LLMError

    ValError --> Start
    LLMError --> Start

    style ValError fill:#E74C3C,color:#fff
    style LLMError fill:#E74C3C,color:#fff
    style Success fill:#50C878,color:#fff
```

**Resilience patterns**:
- Input validation prevents invalid data entering system
- LLM client retries with exponential backoff (1s, 2s, 4s)
- Timeout: 30 seconds per LLM call
- Graceful degradation: Mock data if API unavailable

See [ADR-002: Mock LLM Fallback](../ADR-002-mock-llm-fallback.md)

## Performance Characteristics

| Phase | Typical Duration | Bottleneck | Optimization |
|-------|------------------|------------|--------------|
| Idea Collection | 1-5 minutes | User input | N/A (human speed) |
| Validation | < 1ms | UTF-8 scan | Negligible overhead |
| Vertex Creation | < 10ms | Memory allocation | O(n) complexity |
| LLM Analysis | 5-30 seconds | Network + LLM processing | Caching, parallel requests |
| Edge Creation | < 10ms | Memory allocation | O(m) complexity |
| Layout Calculation | < 1 second | Force-directed iterations | Tested up to 100 nodes |
| Rendering | < 16ms | Terminal refresh rate | 60 FPS capable |

**Scalability**:
- Tested with 10×10 ideas (100 potential edges)
- Layout algorithm: O(n² × iterations)
- Memory: O(n + m) where n=vertices, m=edges

## State Transitions

```mermaid
stateDiagram-v2
    [*] --> MainMenu
    MainMenu --> InputGroupA: Press '1'
    MainMenu --> InputGroupB: Press '2'
    MainMenu --> Analyzing: Press 'a'
    MainMenu --> GraphView: Press 'v'
    MainMenu --> [*]: Press 'q'

    InputGroupA --> MainMenu: ESC
    InputGroupB --> MainMenu: ESC

    Analyzing --> MainMenu: Complete
    Analyzing --> Error: LLM Failure
    Error --> MainMenu: Acknowledge

    GraphView --> MainMenu: 'h' or ESC
    GraphView --> [*]: Press 'q'

    note right of Analyzing
        Blocking operation
        Shows progress
        Retry on failure
    end note

    note right of GraphView
        Non-blocking
        Arrow key navigation
        Real-time updates
    end note
```

## Data Flow

```mermaid
graph LR
    subgraph "Input"
        I1[Group A Ideas]
        I2[Group B Ideas]
    end

    subgraph "Processing"
        V[Validation]
        S[Service Layer]
        L[LLM Client]
    end

    subgraph "Domain"
        G[Graph Engine]
        Vert[Vertices]
        Edge[Edges]
    end

    subgraph "Output"
        Layout[Layout Data]
        Render[Rendered TUI]
    end

    I1 --> V
    I2 --> V
    V --> S
    S --> L
    L --> S
    S --> G
    G --> Vert
    G --> Edge
    Vert --> Layout
    Edge --> Layout
    Layout --> Render

    style V fill:#E74C3C,color:#fff
    style S fill:#9B59B6,color:#fff
    style G fill:#50C878,color:#fff
    style Render fill:#4A90E2,color:#fff
```

## References

- [System Context Diagram](./system-context.md) - High-level architecture
- [UI State Machine Diagram](./ui-state-machine.md) - Detailed UI states
- [Graph Layout Diagram](./graph-layout.md) - Layout algorithm details
- [ADR-005: Service Layer Extraction](../ADR-005-service-layer-extraction.md)
- [Integration Tests](../../tests/integration/workflow_test.zig) - Automated workflow tests

---

**Accessibility Note**: This diagram uses sequence numbering and clear labels. Each phase is explicitly marked with comments in the Mermaid source.
