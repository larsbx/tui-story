# ADR-003: Force-Directed Graph Layout Algorithm

## Status

Accepted

## Context

The semantic relationship graph needs to be visualized in the terminal. Graph layout algorithms determine node positioning to create readable visualizations. Key requirements:

- Minimize edge crossings
- Group vertices by their original group (Group A vs Group B)
- Complete within reasonable time (<100ms for typical graphs)
- Work within terminal constraints (character grid, limited space)
- Bounded iterations to prevent infinite loops

## Decision

Implement a **simplified force-directed layout algorithm** with group constraints:

1. **Initial positioning**: Place Group A vertices on left (x=25%), Group B on right (x=75%)
2. **Repulsive forces**: All vertices repel each other (prevent overlaps)
3. **Group constraints**: Vertices are pulled toward their group's x-position
4. **Fixed iterations**: Maximum 50 iterations regardless of convergence
5. **Boundary enforcement**: Vertices clamped within terminal bounds

See `src/graph.zig:calculateLayout()` for implementation.

## Consequences

### Positive

- **Visually clear**: Left-right separation makes group distinction obvious
- **Predictable performance**: Fixed iterations = O(n²×50) complexity
- **No overlaps**: Repulsive forces prevent vertices from overlapping
- **Simple implementation**: ~60 lines of code, easy to understand and maintain
- **Good enough**: Produces readable layouts for typical use (10-50 nodes)

### Negative

- **Suboptimal layout**: May not minimize edge crossings optimally
- **Scalability limit**: O(n²) repulsion calculation doesn't scale beyond ~100 nodes
- **No edge forces**: Doesn't consider edges in layout (only repulsion)
- **Fixed aesthetics**: Limited customization of layout parameters

### Neutral

- Trade-off between quality and performance acceptable for TUI use case

## Alternatives Considered

### Alternative 1: Sugiyama (layered) layout

- Hierarchical layout algorithm
- **Rejected**: Assumes DAG structure, our graphs may have cycles

### Alternative 2: Spring-embedder with edge springs

- Models edges as springs, adds attractive forces
- **Rejected**: More complex, edge forces complicate group separation

### Alternative 3: Static grid layout

- Position vertices in fixed grid positions
- **Rejected**: Doesn't adapt to graph structure, wasteful of space

### Alternative 4: GraphViz via external process

- Use mature graphviz library for layout
- **Rejected**: External dependency, FFI complexity, overkill for TUI

### Alternative 5: Stress minimization (Kamada-Kawai)

- Optimizes graph-theoretic distance preservation
- **Rejected**: More computationally expensive, unnecessary for our scale

## Notes

- Layout calculation is invoked in `src/ui.zig:renderGraph()` before rendering
- Performance test added in `tests/unit/architecture_test.zig` to ensure layout completes quickly
- Future optimization: Spatial partitioning (quadtree) could reduce repulsion from O(n²) to O(n log n)
- Constants:
  - `iterations = 50`: Balance between quality and speed
  - `k = sqrt(width * height / n)`: Ideal vertex spacing
  - Group x-positions: 0.25 and 0.75 (proportional to width)

## Date

2024-11-20
