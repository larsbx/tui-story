# Architecture Diagrams

This directory contains visual documentation of the tui-story architecture using Mermaid diagrams. These diagrams are rendered automatically on GitHub and in the mdBook documentation.

## Diagram Index

| Diagram | Purpose | Principle |
|---------|---------|-----------|
| [System Context](./system-context.md) | High-level system overview | X. Visual Communication |
| [Analysis Workflow](./analysis-workflow.md) | End-to-end analysis process | X. Visual Communication |
| [Graph Layout](./graph-layout.md) | Force-directed layout algorithm | X. Visual Communication |
| [UI State Machine](./ui-state-machine.md) | TUI navigation flow | X. Visual Communication |
| [Module Dependencies](./module-dependencies.md) | Code module relationships | I. Architecture as Constraints |

## Viewing Diagrams

### On GitHub
Mermaid diagrams render automatically when viewing `.md` files on GitHub.

### In mdBook
The diagrams are embedded in the documentation site and render in the browser.

### Locally
Use a Markdown viewer with Mermaid support:
- VS Code with "Markdown Preview Mermaid Support" extension
- [Mermaid Live Editor](https://mermaid.live/)

## Updating Diagrams

When code changes affect architecture:

1. **Update relevant diagram** in this directory
2. **Reference in ADR** if architectural decision changes
3. **Update date** in diagram frontmatter
4. **Test rendering** on GitHub preview before committing

## Diagram Standards

Following Content & Communication Manifesto Principle X:

- **Alt text**: Every diagram has descriptive alt text
- **Context**: Each diagram includes title, description, legend
- **Currency**: Diagrams include "Last updated" date
- **Accessibility**: Use shapes/labels, not just colors
- **Simplicity**: One concept per diagram; avoid clutter

---

**Last Updated**: 2025-11-20
