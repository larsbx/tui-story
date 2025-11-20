# Semantic Relationship Graph TUI

A terminal user interface (TUI) application built with Zig and libvaxis that analyzes semantic relationships between groups of ideas using LLMs and displays them as an interactive graph.

## Features

- **Dual Group Input**: Enter two groups of ideas (concepts, statements, etc.)
- **LLM-Powered Analysis**: Uses large language models to identify semantic relationships
- **Graph Visualization**: Displays relationships as vertices (ideas) and edges (relationships)
- **9 Relationship Types**:
  - **CONTRADICTORY** (⊥): Ideas that cannot both be true
  - **IMPLICATIVE** (→): One idea logically implies another
  - **HIERARCHICAL** (⊆): One idea is a specific case of another
  - **EVOLUTIONARY** (⟿): One idea developed from another
  - **ANALOGOUS** (≈): Ideas share structural similarity
  - **SYNONYMOUS** (≡): Ideas mean the same thing
  - **ANTONYMOUS** (≠): Ideas are opposites
  - **PART_WHOLE** (∈): One idea is part of another
  - **CAUSAL** (⇒): One idea causes another

- **Interactive Navigation**: Browse relationships with arrow keys
- **Certainty Scores**: Each relationship includes a confidence level

## Requirements

- Zig 0.13.0 or later
- Terminal with Unicode support
- (Optional) Anthropic API key for real LLM analysis

## Installation

1. Install Zig:
```bash
# Download Zig 0.13.0
wget https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz
tar -xf zig-linux-x86_64-0.13.0.tar.xz
export PATH="$PWD/zig-linux-x86_64-0.13.0:$PATH"
```

2. Clone and build:
```bash
git clone <repository-url>
cd tui-story
zig build
```

## Usage

### Run the application:
```bash
zig build run
```

### Optional: Set API key for real LLM analysis
```bash
export ANTHROPIC_API_KEY="your-api-key-here"
zig build run
```

Without an API key, the application uses mock data for demonstration.

### Controls

**Main Menu:**
- `1` - Add ideas to Group A
- `2` - Add ideas to Group B
- `a` - Analyze relationships between groups
- `v` - View the relationship graph
- `r` - Reset all data
- `q` - Quit application

**Input Mode:**
- Type your idea and press `Enter` to add it
- `Esc` - Return to main menu

**Graph View:**
- `↑↓` - Navigate between relationships
- `h` or `Esc` - Return to main menu
- `q` - Quit application

## Example Usage

1. Press `1` to enter Group A ideas:
   - "Democracy"
   - "Representative government"
   - "Citizen participation"

2. Press `2` to enter Group B ideas:
   - "Authoritarianism"
   - "Centralized control"
   - "Limited freedoms"

3. Press `a` to analyze - the LLM will identify relationships like:
   - Democracy ⊥ Authoritarianism (CONTRADICTORY)
   - Representative government ⊆ Democracy (HIERARCHICAL)
   - Authoritarianism ⇒ Limited freedoms (CAUSAL)

4. Press `v` to view the graph visualization

## Architecture

### File Structure
```
tui-story/
├── build.zig          # Build configuration
├── build.zig.zon      # Dependencies (libvaxis)
└── src/
    ├── main.zig       # Application entry point and event loop
    ├── graph.zig      # Graph data structures (vertices, edges)
    ├── llm.zig        # LLM API client
    └── ui.zig         # User interface rendering
```

### Data Structures

**Vertex (Node):**
- Represents an idea/concept
- Has position (x, y) for layout
- Belongs to group 0 or 1

**Edge (Relationship):**
- Connects two vertices
- Has a relationship type
- Includes certainty score (0.0 - 1.0)
- Contains description/justification

**SemanticGraph:**
- Manages vertices and edges
- Implements force-directed layout algorithm
- Groups ideas visually by their original group

## Extending the Application

### Adding New Relationship Types

Edit `src/graph.zig` and add to the `RelationType` enum:

```zig
pub const RelationType = enum {
    // ... existing types ...
    your_new_type,

    pub fn toString(self: RelationType) []const u8 {
        return switch (self) {
            // ... existing cases ...
            .your_new_type => "YOUR_NEW_TYPE",
        };
    }

    pub fn getSymbol(self: RelationType) []const u8 {
        return switch (self) {
            // ... existing cases ...
            .your_new_type => "★",
        };
    }
};
```

### Implementing Real LLM Integration

Edit `src/llm.zig` and implement the `callAPI` and `parseResponse` functions:

```zig
fn callAPI(self: *LLMClient, prompt: []const u8) ![]const u8 {
    // Use std.http.Client to make API calls
    // Format request according to your LLM provider's API
    // Return the JSON response
}

fn parseResponse(self: *LLMClient, response: []const u8) ![]Relationship {
    // Parse JSON response
    // Extract relationships
    // Return array of Relationship structs
}
```

### Customizing Graph Layout

Edit the `calculateLayout` function in `src/graph.zig` to adjust:
- Initial positioning
- Force-directed algorithm parameters
- Group separation distance

## License

MIT

## Contributing

Contributions welcome! Please feel free to submit issues or pull requests.

## Credits

Built with:
- [Zig](https://ziglang.org/) - Programming language
- [libvaxis](https://github.com/rockorager/libvaxis) - Terminal UI library
