# ADR-004: Input Validation Layer

## Status

Accepted

## Context

User input poses several risks:

- **Empty input**: Breaks graph vertices, causes display issues
- **Excessively long input**: Memory exhaustion, DoS attacks
- **Invalid UTF-8**: Encoding attacks, terminal corruption
- **Invalid group numbers**: Out-of-bounds errors in layout algorithm

These must be validated at system boundaries to prevent security issues and runtime errors.

## Decision

Create a dedicated **validation module** (`src/validation.zig`) with:

1. **Validation functions**: `validateIdea()`, `validateGroup()`, `validateVertexContent()`
2. **Security limits**: `MAX_IDEA_LENGTH = 1000` characters
3. **UTF-8 validation**: Use `std.unicode.utf8ValidateSlice()`
4. **Sanitization**: `sanitizeInput()` trims whitespace
5. **Integration**: Validation at UI layer (input) and domain layer (graph)

```zig
// UI layer validation (src/ui.zig)
validation.validateIdea(input) catch |err| {
    self.error_message = "Error: ...";
    return;
};

// Domain layer validation (src/graph.zig)
try validation.validateVertexContent(content);
try validation.validateGroup(group);
```

## Consequences

### Positive

- **Defense in depth**: Validation at multiple layers
- **Clear error messages**: Users see specific validation failures
- **Security hardening**: Prevents DoS, encoding attacks
- **Centralized logic**: All validation rules in one module
- **Testable**: Validation module has comprehensive unit tests

### Negative

- **Duplicate checks**: Some validation happens at both UI and domain layers
- **Overhead**: Every input validated (minimal performance impact)
- **Magic number**: MAX_IDEA_LENGTH=1000 is somewhat arbitrary

### Neutral

- Slight increase in code complexity for significant security benefit

## Alternatives Considered

### Alternative 1: No validation

- **Rejected**: Security risk, poor user experience

### Alternative 2: Only UI validation

- **Rejected**: No defense against programmatic misuse, violates domain integrity

### Alternative 3: Only domain validation

- **Rejected**: Poor UX (errors at graph layer instead of input layer)

### Alternative 4: Runtime constraint framework

- Build generic validation DSL
- **Rejected**: Over-engineering for current needs

## Notes

- `MAX_IDEA_LENGTH = 1000` chosen as reasonable limit for terminal display
- Error messages displayed in red bold text (see `src/ui.zig:renderInput()`)
- Architecture tests verify validation enforces security constraints
- Future: Could add profanity filtering, URL validation, etc. in validation module

## Date

2024-11-20
