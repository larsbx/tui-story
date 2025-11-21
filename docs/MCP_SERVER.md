# MCP Server Mode

The Semantic Graph TUI now supports running as a headless **Model Context Protocol (MCP)** server, enabling integration with Claude and other LLM applications.

## What is MCP?

The [Model Context Protocol](https://modelcontextprotocol.io) is an open standard developed by Anthropic for connecting AI assistants to external tools and data sources. It uses JSON-RPC 2.0 over stdio/HTTP transports.

## Running in MCP Mode

### Stdio Mode (Single Client)

Start the server in headless stdio MCP mode:

```bash
./semantic-graph-tui --mcp
```

Or use the short flag:

```bash
./semantic-graph-tui -m
```

The server will:
- Read JSON-RPC 2.0 messages from **stdin**
- Write responses to **stdout**
- Log diagnostic messages to **stderr**
- Support **one client at a time**

### HTTP Mode (Multiple Concurrent Clients) 🆕

Start the server in HTTP mode for **concurrent multi-client access**:

```bash
./semantic-graph-tui --http
```

Or specify a custom port:

```bash
./semantic-graph-tui --http 8080
```

The HTTP server will:
- Listen on `http://127.0.0.1:3000` (default port)
- Accept JSON-RPC 2.0 requests via HTTP POST
- Support **multiple AI models accessing concurrently**
- Provide **thread-safe** graph access with automatic synchronization
- Log diagnostic messages to **stderr**

**When to use HTTP mode:**
- Multiple AI agents need to collaborate on the same semantic graph
- You want multiple LLM applications to access the graph simultaneously
- You need programmatic access from scripts or tools
- You're building a multi-agent system

**When to use stdio mode:**
- Single Claude Desktop integration
- One-on-one agent communication
- Claude Code or similar single-agent tools

## MCP Tools

The server exposes the following tools:

### 1. `add_idea`

Add a new concept to the semantic graph.

**Input Schema:**
```json
{
  "content": "string (1-1000 characters)"
}
```

**Example:**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "add_idea",
    "arguments": {
      "content": "Machine Learning"
    }
  }
}
```

### 2. `analyze_idea`

Analyze a new idea against all existing ideas in the graph to discover semantic relationships.

**Input Schema:**
```json
{
  "content": "string (1-1000 characters)"
}
```

**Example:**
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/call",
  "params": {
    "name": "analyze_idea",
    "arguments": {
      "content": "Neural Networks"
    }
  }
}
```

### 3. `get_graph`

Retrieve the complete semantic graph state including all vertices and edges.

**Input Schema:**
```json
{}
```

**Example:**
```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "tools/call",
  "params": {
    "name": "get_graph",
    "arguments": {}
  }
}
```

### 4. `list_ideas`

List all concepts/ideas currently in the graph.

**Input Schema:**
```json
{}
```

**Example:**
```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "method": "tools/call",
  "params": {
    "name": "list_ideas",
    "arguments": {}
  }
}
```

### 5. `reset_graph`

Clear all data from the semantic graph.

**Input Schema:**
```json
{}
```

**Example:**
```json
{
  "jsonrpc": "2.0",
  "id": 5,
  "method": "tools/call",
  "params": {
    "name": "reset_graph",
    "arguments": {}
  }
}
```

## MCP Resources

The server exposes the following resources for read access:

### 1. `graph://state`

Complete graph state including vertices and edges in JSON format.

**Example:**
```json
{
  "jsonrpc": "2.0",
  "id": 6,
  "method": "resources/read",
  "params": {
    "uri": "graph://state"
  }
}
```

### 2. `graph://vertices`

List of all vertices (concepts) in the graph.

**Example:**
```json
{
  "jsonrpc": "2.0",
  "id": 7,
  "method": "resources/read",
  "params": {
    "uri": "graph://vertices"
  }
}
```

### 3. `graph://edges`

List of all edges (semantic relationships) in the graph.

**Example:**
```json
{
  "jsonrpc": "2.0",
  "id": 8,
  "method": "resources/read",
  "params": {
    "uri": "graph://edges"
  }
}
```

## MCP Protocol Methods

The server implements the following MCP protocol methods:

### `initialize`

Establish connection and retrieve server capabilities.

**Example:**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {}
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "protocolVersion": "2025-06-18",
    "serverInfo": {
      "name": "semantic-graph-tui",
      "version": "0.1.0"
    },
    "capabilities": {
      "tools": {
        "listChanged": false
      },
      "resources": {
        "subscribe": false,
        "listChanged": false
      }
    }
  }
}
```

### `tools/list`

List all available tools.

**Example:**
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/list"
}
```

### `tools/call`

Execute a specific tool.

**Example:**
```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "tools/call",
  "params": {
    "name": "add_idea",
    "arguments": {
      "content": "Distributed Systems"
    }
  }
}
```

### `resources/list`

List all available resources.

**Example:**
```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "method": "resources/list"
}
```

### `resources/read`

Read a specific resource.

**Example:**
```json
{
  "jsonrpc": "2.0",
  "id": 5,
  "method": "resources/read",
  "params": {
    "uri": "graph://state"
  }
}
```

### `ping`

Health check endpoint.

**Example:**
```json
{
  "jsonrpc": "2.0",
  "id": 6,
  "method": "ping"
}
```

## Integration Examples

### Claude Desktop (Stdio Mode)

To use this server with Claude Desktop, add it to your MCP configuration:

**macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`

**Windows:** `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "semantic-graph": {
      "command": "/path/to/semantic-graph-tui",
      "args": ["--mcp"],
      "env": {
        "ANTHROPIC_API_KEY": "your-api-key-here",
        "LLM_PROVIDER": "anthropic",
        "LLM_MODEL": "claude-3-5-sonnet-20241022"
      }
    }
  }
}
```

After adding this configuration and restarting Claude Desktop, you can ask Claude to:

- "Add the concept 'Quantum Computing' to the semantic graph"
- "Analyze how 'Machine Learning' relates to existing concepts"
- "Show me the current semantic graph"
- "List all ideas in the graph"

### HTTP Mode: Multiple Clients

Start the HTTP server:

```bash
./semantic-graph-tui --http 3000 &
```

Then multiple clients can connect:

**Client 1 - curl:**
```bash
curl -X POST http://127.0.0.1:3000 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"add_idea","arguments":{"content":"Distributed Systems"}}}'
```

**Client 2 - Python:**
```python
import requests

response = requests.post('http://127.0.0.1:3000', json={
    "jsonrpc": "2.0",
    "id": 2,
    "method": "tools/call",
    "params": {
        "name": "add_idea",
        "arguments": {"content": "Consensus Algorithms"}
    }
})

print(response.json())
```

**Client 3 - JavaScript:**
```javascript
fetch('http://127.0.0.1:3000', {
  method: 'POST',
  headers: {'Content-Type': 'application/json'},
  body: JSON.stringify({
    jsonrpc: '2.0',
    id: 3,
    method: 'tools/call',
    params: {
      name: 'list_ideas',
      arguments: {}
    }
  })
})
.then(r => r.json())
.then(data => console.log(data));
```

All three clients can work simultaneously on the same semantic graph!

## Multi-Agent Support

### HTTP Mode: True Concurrent Access

The HTTP MCP server supports **multiple concurrent agents** working with the same graph simultaneously:

- **Thread-safe operations**: All graph operations are protected by mutex locks
- **Concurrent requests**: Multiple AI models can send requests at the same time
- **Shared state**: All agents see the same semantic graph in real-time
- **Atomic operations**: Each request is processed atomically to maintain data consistency

**Example: Multiple agents collaborating**

Agent 1 (GPT-4):
```bash
curl -X POST http://127.0.0.1:3000 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"add_idea","arguments":{"content":"Machine Learning"}}}'
```

Agent 2 (Claude):
```bash
curl -X POST http://127.0.0.1:3000 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"add_idea","arguments":{"content":"Neural Networks"}}}'
```

Both agents can work simultaneously, and both will see each other's contributions to the graph.

### Stdio Mode: Sequential Access

The stdio MCP server supports single-client access. For multi-agent collaboration, use HTTP mode.

## Environment Variables

Configure the LLM provider used for semantic analysis:

- `LLM_PROVIDER`: Provider name (`anthropic`, `openai`, `custom`)
- `LLM_MODEL`: Model name (default: `claude-3-5-sonnet-20241022`)
- `LLM_API_ENDPOINT`: Custom API endpoint (for `custom` provider)
- `ANTHROPIC_API_KEY`: Anthropic API key
- `OPENAI_API_KEY`: OpenAI API key

## Error Handling

The server returns standard JSON-RPC 2.0 error codes:

- `-32600`: Invalid Request
- `-32601`: Method not found
- `-32602`: Invalid params
- `-32603`: Internal error

**Example error response:**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32602,
    "message": "Missing 'content' argument"
  }
}
```

## Testing

Run the MCP server tests:

```bash
zig build test
```

This includes:
- Unit tests for JSON-RPC message handling
- Integration tests for complete protocol flows
- Multi-agent collaboration tests
- Concurrent access tests (HTTP mode)
- Thread-safe graph operation tests
- Error handling tests

**Test Coverage:**
- 15 stdio MCP server tests
- 4 MCP protocol integration tests
- 14 thread-safe graph tests
- 11 concurrent HTTP server tests
- **Total: 44 MCP-related tests**

## Architecture

The MCP server has two implementations:

### Stdio Mode (`src/mcp_server.zig`)
- Single-client JSON-RPC 2.0 over stdin/stdout
- Direct access to `SemanticGraph`
- Synchronous request processing

### HTTP Mode (`src/mcp_server_concurrent.zig`)
- Multi-client JSON-RPC 2.0 over HTTP
- Uses `ThreadSafeGraph` wrapper (`src/thread_safe_graph.zig`)
- Concurrent request processing with thread spawning
- Mutex-protected graph operations

Both reuse the existing:

- **Domain layer**: `graph.zig` - Semantic graph data structures
- **Application layer**: `analysis_service.zig` - Business logic
- **Infrastructure layer**: `llm.zig` - LLM API client
- **Validation layer**: `validation.zig` - Input validation
- **Thread-safety layer**: `thread_safe_graph.zig` - Synchronized graph access (HTTP mode only)

This clean separation allows TUI, stdio MCP, and HTTP MCP modes to share the same core functionality.

## Learn More

- [Model Context Protocol Specification](https://modelcontextprotocol.io/specification/2025-06-18)
- [MCP GitHub Repository](https://github.com/modelcontextprotocol)
- [Anthropic MCP Documentation](https://www.anthropic.com/news/model-context-protocol)
