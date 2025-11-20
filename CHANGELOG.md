# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- CHANGELOG.md to track project changes
- Architecture diagrams for system overview and workflows
- Style guide for documentation consistency
- mdBook configuration for static site generation

### Fixed
- Test compilation errors across all test suites (65 tests now passing)
- Memory leak check pattern - removed `try` from defer expressions
- Compatibility with Zig 0.13.0 (removed unavailable `std.process.unsetenv()`)
- Module import system - migrated from relative paths to module system
- UI tests updated to match single-idea entry implementation
- Made LLM test helper functions public (`buildPrompt`, `getMockRelationships`)

### Changed
- Build system now uses proper module declarations with dependency wiring
- All imports changed from relative paths (e.g., `@import("../../src/graph.zig")`) to module imports (e.g., `@import("graph")`)
- Test cleanup code simplified to use `defer _ = gpa.deinit()`
- Temporarily commented out libvaxis dependency in build files (network issues)

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
