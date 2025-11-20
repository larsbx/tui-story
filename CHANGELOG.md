# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Formal Verification Manifesto v1.1 with 16 foundational principles
- Executive Summary for engineering leadership on formal methods adoption
- Comprehensive TLA+ formal specifications:
  - SemanticGraphTUI.tla: Main system specification with UI state machine
  - SemanticGraphConstraints.tla: Graph data structure constraints
  - LLMRetryLogic.tla: LLM API retry mechanism with exponential backoff
  - ValidationLayer.tla: Input validation and security boundaries
- TLC model checker configurations for all specifications
- Semantic analysis documentation with 26 invariants and 13 properties
- Decision tree for formal verification tool selection
- Learning paths for practitioners, researchers, and managers
- Common pitfalls and open research problems in formal methods
- Multiple relationship support between same nodes
- Edge query methods: `hasEdge()`, `getEdgesBetween()`, `findEdge()`
- Intelligent duplicate edge prevention with certainty-based updates
- CHANGELOG.md to track project changes
- Architecture diagrams for system overview and workflows
- Style guide for documentation consistency
- mdBook configuration for static site generation

### Changed
- **BREAKING**: Replaced dual-group entry with single idea incremental workflow
- Each new idea is now automatically compared to all existing ideas
- UI modes simplified: single input mode instead of separate group1/group2 modes
- Key bindings updated: `e` to enter idea (removed `1`, `2`, `a` keys)
- Single color for all vertices (removed group-based coloring)
- Graph now builds incrementally with dense connectivity
- Build system now uses proper module declarations with dependency wiring
- All imports changed from relative paths to module imports
- Test cleanup code simplified to use `defer _ = gpa.deinit()`

### Fixed
- Test compilation errors across all test suites (65 tests now passing)
- Memory leak check pattern - removed `try` from defer expressions
- Compatibility with Zig 0.13.0 (removed unavailable `std.process.unsetenv()`)
- Module import system - migrated from relative paths to module system
- UI tests updated to match single-idea entry implementation
- Made LLM test helper functions public (`buildPrompt`, `getMockRelationships`)
- Re-enabled libvaxis dependency and main executable build in build configuration

### Documentation
- Added specs/README.md with comprehensive TLA+ specification guide
- Added specs/SEMANTIC_ANALYSIS.md with detailed invariant analysis
- Added docs/FORMAL_VERIFICATION_MANIFESTO.md
- Added docs/EXECUTIVE_SUMMARY.md for managers and executives
- Enhanced help text to reflect incremental approach

### Testing
- Added 13 new tests for multiple relationships and edge queries
- Added 295 lines of test coverage for graph relationship handling
- Integration tests updated for incremental workflow

## [0.3.0] - 2025-11-20

### Added
- Input validation layer for security (`src/validation.zig`)
- Structured logging throughout application
- Service layer extraction (`src/analysis_service.zig`)
- Timeout and retry logic for LLM client
- Architecture tests for boundary verification
- Integration tests for complete workflow
- Architecture Decision Records (ADRs) in `docs/architecture/`
- IMPLEMENTATION_SUMMARY.md documenting architectural improvements

### Changed
- UI layer now delegates business logic to service layer
- LLM client includes exponential backoff on failures
- Graph validates inputs at domain boundary

### Improved
- Observability: Added scoped logging (3/10 → 7/10)
- Resilience: Added retry/timeout patterns (5/10 → 7/10)
- Security: Added input validation at boundaries (6/10 → 8/10)
- Architecture constraints: Added fitness functions (6/10 → 8/10)

### Testing
- 69+ total tests (up from 52)
- 10 new architecture tests
- 7 new integration tests

**Architecture Score**: 78/100 → 88/100

## [0.2.0] - 2025-11-19

### Added
- Comprehensive testing infrastructure
- Unit tests for graph, LLM, and UI modules (52 tests)
- GitHub Actions CI pipeline
- Test structure: `tests/unit/`, `tests/integration/`, `tests/fixtures/`
- Memory safety validation using GeneralPurposeAllocator
- Code formatting checks in CI (`zig fmt --check`)
- EXAMPLES.md with 5 domain-specific use cases

### Testing
- Graph module: 21 tests
- LLM module: 16 tests
- UI module: 15 tests
- CI runs on Ubuntu and macOS

### Documentation
- Expanded README.md with testing section
- Added test coverage documentation
- Documented test structure and writing guidelines

## [0.1.0] - 2025-11-18

### Added
- Initial release of Semantic Relationship Graph TUI
- Dual group input for ideas/concepts
- LLM-powered semantic relationship analysis
- Graph visualization with 9 relationship types:
  - CONTRADICTORY (⊥)
  - IMPLICATIVE (→)
  - HIERARCHICAL (⊆)
  - EVOLUTIONARY (⟿)
  - ANALOGOUS (≈)
  - SYNONYMOUS (≡)
  - ANTONYMOUS (≠)
  - PART_WHOLE (∈)
  - CAUSAL (⇒)
- Interactive TUI navigation with arrow keys
- Certainty scores for each relationship
- Mock LLM fallback for development without API key
- Force-directed graph layout algorithm

### Core Modules
- `src/main.zig`: Application entry point and event loop
- `src/graph.zig`: Graph data structures (vertices, edges)
- `src/llm.zig`: LLM API client with mock fallback
- `src/ui.zig`: User interface rendering

### Requirements
- Zig 0.13.0 or later
- Terminal with Unicode support
- Optional: Anthropic API key for real LLM analysis

### Dependencies
- libvaxis for terminal UI

---

## Versioning Guidelines

This project uses [Semantic Versioning](https://semver.org/):
- **MAJOR** version: Incompatible API changes
- **MINOR** version: New functionality (backward compatible)
- **PATCH** version: Bug fixes (backward compatible)

## Contributing to Changelog

When contributing, please update the `[Unreleased]` section with your changes:

### Categories
- **Added**: New features
- **Changed**: Changes to existing functionality
- **Deprecated**: Features that will be removed in future versions
- **Removed**: Features removed in this version
- **Fixed**: Bug fixes
- **Security**: Security vulnerability fixes

### Format
```markdown
### Added
- Feature description ([#123](link-to-issue))
```

---

## Links

- [Keep a Changelog](https://keepachangelog.com/)
- [Semantic Versioning](https://semver.org/)
- [GitHub Repository](https://github.com/larsbx/tui-story)
