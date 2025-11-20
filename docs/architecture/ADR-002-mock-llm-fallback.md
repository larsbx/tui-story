# ADR-002: Mock LLM Fallback for Development

## Status

Accepted

## Context

The application requires LLM (Large Language Model) API access to analyze semantic relationships between ideas. However:

- Developers may not have API keys during initial development
- API calls cost money
- Tests should run without external dependencies
- Demos should work without internet connectivity
- Development iteration should be fast

We need a strategy that allows development and testing without requiring actual LLM API access.

## Decision

Implement a **mock LLM client** that generates deterministic relationship data when no API key is present. The `LLMClient` checks for the `ANTHROPIC_API_KEY` environment variable and falls back to mock data generation if not found.

```zig
pub fn analyzeRelationships(...) ![]Relationship {
    if (self.api_key == null) {
        return try self.getMockRelationships(group1, group2);
    }
    // Real API call...
}
```

## Consequences

### Positive

- **Zero-friction onboarding**: New developers can run the app immediately
- **Fast iteration**: No network latency during development
- **Cost-effective**: No API charges for development/testing
- **Offline demos**: Can demonstrate functionality without internet
- **Deterministic testing**: Tests produce consistent results
- **Graceful degradation**: App remains functional without API key

### Negative

- **Mock data unrealistic**: Generated relationships may not match LLM quality
- **Two code paths**: Must maintain both mock and real implementations
- **False confidence**: Developers might not test against real API
- **Divergence risk**: Mock implementation could drift from real behavior

### Neutral

- Code complexity slightly increased by dual implementation

## Alternatives Considered

### Alternative 1: Require API key always

- **Rejected**: Creates friction for new developers, makes testing expensive

### Alternative 2: Recorded API responses (fixtures)

- **Rejected**: Would need many fixtures for different test scenarios, becomes stale

### Alternative 3: Local LLM (ollama, llama.cpp)

- **Rejected**: Requires significant local resources, complex setup

### Alternative 4: Separate mock binary

- **Rejected**: More complex build configuration, users need to know which to run

## Notes

- Mock implementation is in `src/llm.zig:getMockRelationships()`
- Generates relationships using simple heuristics based on array indices
- Logging clearly indicates when mock mode is active: `"LLM client initialized without API key - using mock data"`
- Future: Could add environment variable to force mock mode even with API key (useful for testing)

## Date

2024-11-20
