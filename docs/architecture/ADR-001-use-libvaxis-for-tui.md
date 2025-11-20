# ADR-001: Use libvaxis for Terminal User Interface

## Status

Accepted

## Context

The application needs a terminal user interface (TUI) to display semantic relationship graphs interactively. The TUI must support:

- Unicode characters for relationship symbols (⊥, →, ⇒, etc.)
- Cross-platform terminal compatibility
- Keyboard event handling
- Window resizing
- Color support for visual differentiation

Several TUI libraries exist with different trade-offs in maturity, features, and Zig integration.

## Decision

We will use [libvaxis](https://github.com/rockorager/libvaxis) as our TUI framework.

## Consequences

### Positive

- **Native Zig integration**: Built specifically for Zig, follows Zig idioms and patterns
- **Unicode support**: Full support for the Unicode relationship symbols we need
- **Modern API**: Clean, ergonomic API design that fits our use case
- **Active development**: Maintained and improving
- **Cross-platform**: Works on Linux, macOS, and Windows

### Negative

- **Less mature**: Younger library compared to ncurses or notcurses
- **Smaller community**: Fewer examples and less Stack Overflow coverage
- **Breaking changes possible**: API may evolve as library matures

### Neutral

- Learning curve is similar to other TUI libraries

## Alternatives Considered

### Alternative 1: notcurses

- Mature, feature-rich C library
- **Rejected**: C FFI complexity, heavier than needed for our use case

### Alternative 2: termbox/termbox-next

- Simple, lightweight API
- **Rejected**: Limited Unicode support, less active maintenance

### Alternative 3: Raw ANSI escape sequences

- Maximum control and minimal dependencies
- **Rejected**: Would require implementing windowing, event handling, and cross-platform compatibility ourselves

### Alternative 4: ncurses via C FFI

- Industry standard, extremely mature
- **Rejected**: C FFI complexity, overkill for our needs, less idiomatic Zig code

## Notes

- libvaxis is specified in `build.zig.zon` as a dependency
- Documentation: https://github.com/rockorager/libvaxis
- Imported in code as: `const vaxis = @import("vaxis");`

## Date

2024-11-20
