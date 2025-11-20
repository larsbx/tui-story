# Architecture Decision Records

This directory contains Architecture Decision Records (ADRs) documenting significant architectural decisions in the tui-story project.

## What is an ADR?

An ADR is a document that captures an important architectural decision made along with its context and consequences. ADRs help future developers (including your future self) understand *why* decisions were made, not just *what* the decision was.

## ADR Index

| ADR | Title | Status |
|-----|-------|--------|
| [ADR-000](ADR-000-template.md) | Template | Template |
| [ADR-001](ADR-001-use-libvaxis-for-tui.md) | Use libvaxis for Terminal User Interface | Accepted |
| [ADR-002](ADR-002-mock-llm-fallback.md) | Mock LLM Fallback for Development | Accepted |
| [ADR-003](ADR-003-force-directed-graph-layout.md) | Force-Directed Graph Layout Algorithm | Accepted |
| [ADR-004](ADR-004-input-validation-layer.md) | Input Validation Layer | Accepted |
| [ADR-005](ADR-005-service-layer-extraction.md) | Extract Analysis Service from UI Layer | Accepted |

## When to Write an ADR

Create an ADR when you make a decision that:

- Has significant impact on the system's structure
- Is difficult or expensive to reverse
- Affects multiple modules or developers
- Involves trade-offs between competing concerns
- Would benefit from documenting the context and alternatives

## ADR Process

1. Copy `ADR-000-template.md` to `ADR-XXX-title.md` (next available number)
2. Fill in each section:
   - **Context**: Why are we making this decision?
   - **Decision**: What did we decide?
   - **Consequences**: What are the positive, negative, and neutral outcomes?
   - **Alternatives**: What other options did we consider and why did we reject them?
3. Set status to "Proposed"
4. Discuss with team/reviewers
5. Update status to "Accepted" once implemented
6. Add entry to this README

## ADR Statuses

- **Proposed**: Decision proposed but not yet implemented
- **Accepted**: Decision implemented and in use
- **Deprecated**: Decision no longer recommended (but may still be in codebase)
- **Superseded**: Replaced by another ADR

## References

- [Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions) by Michael Nygard
- [ADR GitHub Organization](https://adr.github.io/)
- Software Architecture Manifesto Principle XIII: Documentation as Architecture Artifact
