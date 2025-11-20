# ADR-005: Extract Analysis Service from UI Layer

## Status

Accepted

## Context

The UI layer (`src/ui.zig`) originally contained business logic for orchestrating semantic analysis:

- Building vertex maps from idea lists
- Coordinating LLM client and graph construction
- Managing relationship-to-edge conversion

This violated **Separation of Concerns** (Principle III) - the UI should handle presentation, not business orchestration.

## Decision

Extract business logic into `src/analysis_service.zig`:

- **AnalysisService**: Orchestrates analysis workflow
- **analyzeGroups()**: Coordinates graph construction from LLM results
- **UI delegates**: `UIState.analyzeIdeas()` now calls service

```zig
// Before: UI contains business logic
fn analyzeIdeas(self: *UIState, ...) {
    // 40+ lines of vertex mapping, LLM coordination, edge creation
}

// After: UI delegates to service
fn analyzeIdeas(self: *UIState, ...) {
    try self.analysis.analyzeGroups(
        self.group1_ideas.items,
        self.group2_ideas.items,
        g, llm_client
    );
}
```

## Consequences

### Positive

- **Separation of concerns**: UI focuses on presentation, service handles orchestration
- **Testability**: Business logic testable without UI dependency
- **Reusability**: Service can be called from CLI, API, or other interfaces
- **Single responsibility**: Each module has clear purpose
- **Maintainability**: Business logic changes don't affect UI code

### Negative

- **Additional file**: One more module to navigate
- **Indirection**: One more layer between UI and domain

### Neutral

- Total lines of code unchanged, just reorganized

## Alternatives Considered

### Alternative 1: Keep logic in UI

- **Rejected**: Violates architectural principles, hard to test

### Alternative 2: Move logic to graph module

- **Rejected**: Graph should be data structure, not orchestration

### Alternative 3: Create "use case" objects

- Clean Architecture style use case per operation
- **Rejected**: Over-engineering for current scale

## Notes

- Service pattern from Domain-Driven Design
- Related to Principle III (Separation of Concerns) and Principle XII (Testability)
- Architecture tests verify service works independently of UI
- UIState holds reference to AnalysisService (initialized in constructor)
- Logging moved to service layer where orchestration happens

## Date

2024-11-20
