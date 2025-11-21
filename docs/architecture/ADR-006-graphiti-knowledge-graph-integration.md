# ADR-006: Graphiti Knowledge Graph Integration

## Status

Proposed

## Context

The current tui-story application provides semantic relationship analysis between concepts using LLMs. While effective for small-scale analysis, it has limitations:

- **No temporal context**: Relationships lack time-based information about when concepts were introduced
- **Limited persistence**: Graph data is session-based with basic serialization
- **No episodic memory**: Cannot track how knowledge evolved over time
- **Manual graph operations**: No automatic entity extraction or relationship inference
- **Scaling challenges**: In-memory graph structure limits knowledge base size

**Graphiti** is a Python framework designed specifically for building temporal, episodic knowledge graphs with LLM-powered extraction and reasoning. Core capabilities:

- **Episodic knowledge**: Facts tied to temporal context
- **Entity extraction**: LLM-based entity/relationship identification
- **Graph reasoning**: Semantic search and fact retrieval over graphs
- **Production backends**: Neo4j, FalkorDB (Redis-based graph)
- **Temporal querying**: Track how knowledge evolves over time

Integration with Graphiti could enhance tui-story's capabilities while maintaining Zig's performance for the TUI layer.

## Decision

We propose **Strategy 1: HTTP Service Integration** as the primary architecture, with fallback support for direct graph operations.

### Architecture Overview

```
┌─────────────┐      HTTP/JSON      ┌──────────────┐
│   Zig TUI   │ ←──────────────────→ │   Graphiti   │
│   (Client)  │                      │   Service    │
│  tui-story  │                      │   (FastAPI)  │
└─────────────┘                      └──────┬───────┘
                                            │ Bolt
                                     ┌──────▼───────┐
                                     │    Neo4j     │
                                     │  or FalkorDB │
                                     └──────────────┘
```

### Implementation Components

#### 1. Python Graphiti Service (FastAPI)

```python
from fastapi import FastAPI, HTTPException
from graphiti_core import Graphiti
from pydantic import BaseModel
from typing import List, Optional

app = FastAPI(title="Graphiti Knowledge Graph Service")
graphiti = Graphiti(neo4j_uri="bolt://localhost:7687")

class Episode(BaseModel):
    content: str
    source: Optional[str] = None
    timestamp: Optional[str] = None

class SearchQuery(BaseModel):
    query: str
    limit: int = 10

class Entity(BaseModel):
    name: str
    type: str
    summary: str
    created_at: Optional[str]

class Edge(BaseModel):
    source: str
    target: str
    relation: str
    certainty: float
    description: str

class SearchResult(BaseModel):
    entities: List[Entity]
    edges: List[Edge]

@app.post("/episodes")
async def add_episode(episode: Episode):
    """Add a new episode to the knowledge graph"""
    try:
        await graphiti.add_episode(
            episode.content,
            source=episode.source,
            timestamp=episode.timestamp
        )
        return {"status": "ok", "message": "Episode added successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/search", response_model=SearchResult)
async def search(query: str, limit: int = 10):
    """Search the knowledge graph"""
    try:
        results = await graphiti.search(query, limit=limit)
        return SearchResult(
            entities=[Entity(**e) for e in results.get("entities", [])],
            edges=[Edge(**e) for e in results.get("edges", [])]
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health():
    """Health check endpoint"""
    return {"status": "healthy", "service": "graphiti"}
```

#### 2. Zig HTTP Client

```zig
const std = @import("std");

pub const GraphitiClient = struct {
    allocator: std.mem.Allocator,
    client: std.http.Client,
    base_url: []const u8,

    pub fn init(allocator: std.mem.Allocator, base_url: []const u8) GraphitiClient {
        return .{
            .allocator = allocator,
            .client = std.http.Client{ .allocator = allocator },
            .base_url = base_url,
        };
    }

    pub fn deinit(self: *GraphitiClient) void {
        self.client.deinit();
    }

    pub const Episode = struct {
        content: []const u8,
        source: ?[]const u8 = null,
        timestamp: ?[]const u8 = null,
    };

    pub fn addEpisode(self: *GraphitiClient, episode: Episode) !void {
        const uri_str = try std.fmt.allocPrint(
            self.allocator,
            "{s}/episodes",
            .{self.base_url}
        );
        defer self.allocator.free(uri_str);

        const uri = try std.Uri.parse(uri_str);

        const payload = try std.json.stringifyAlloc(
            self.allocator,
            episode,
            .{}
        );
        defer self.allocator.free(payload);

        var req = try self.client.open(.POST, uri, .{
            .server_header_buffer = try self.allocator.alloc(u8, 4096),
            .extra_headers = &.{
                .{ .name = "content-type", .value = "application/json" },
            },
        });
        defer req.deinit();

        req.transfer_encoding = .{ .content_length = payload.len };
        try req.send();
        try req.writeAll(payload);
        try req.finish();
        try req.wait();

        if (req.response.status != .ok) {
            return error.GraphitiRequestFailed;
        }
    }

    pub const Entity = struct {
        name: []const u8,
        type: []const u8,
        summary: []const u8,
        created_at: ?[]const u8 = null,
    };

    pub const Edge = struct {
        source: []const u8,
        target: []const u8,
        relation: []const u8,
        certainty: f32,
        description: []const u8,
    };

    pub const SearchResult = struct {
        entities: []Entity,
        edges: []Edge,

        pub fn deinit(self: SearchResult, allocator: std.mem.Allocator) void {
            allocator.free(self.entities);
            allocator.free(self.edges);
        }
    };

    pub fn search(self: *GraphitiClient, query: []const u8) !SearchResult {
        // URL encode the query parameter
        const encoded_query = try std.Uri.Component.percentEncodePath(
            self.allocator,
            query
        );
        defer self.allocator.free(encoded_query);

        const uri_str = try std.fmt.allocPrint(
            self.allocator,
            "{s}/search?query={s}",
            .{ self.base_url, encoded_query }
        );
        defer self.allocator.free(uri_str);

        const uri = try std.Uri.parse(uri_str);

        var req = try self.client.open(.GET, uri, .{
            .server_header_buffer = try self.allocator.alloc(u8, 4096),
        });
        defer req.deinit();

        try req.send();
        try req.finish();
        try req.wait();

        if (req.response.status != .ok) {
            return error.GraphitiRequestFailed;
        }

        const body = try req.reader().readAllAlloc(
            self.allocator,
            1024 * 1024 // 1MB max response
        );
        defer self.allocator.free(body);

        const parsed = try std.json.parseFromSlice(
            SearchResult,
            self.allocator,
            body,
            .{}
        );

        return parsed.value;
    }

    pub fn healthCheck(self: *GraphitiClient) !bool {
        const uri_str = try std.fmt.allocPrint(
            self.allocator,
            "{s}/health",
            .{self.base_url}
        );
        defer self.allocator.free(uri_str);

        const uri = try std.Uri.parse(uri_str);

        var req = try self.client.open(.GET, uri, .{
            .server_header_buffer = try self.allocator.alloc(u8, 4096),
        });
        defer req.deinit();

        try req.send();
        try req.finish();
        try req.wait();

        return req.response.status == .ok;
    }
};
```

#### 3. Integration with Existing Analysis Service

```zig
// src/graphiti_integration.zig
const std = @import("std");
const GraphitiClient = @import("graphiti_client.zig").GraphitiClient;
const graph = @import("graph.zig");

pub const GraphitiIntegration = struct {
    client: GraphitiClient,
    enabled: bool,

    pub fn init(allocator: std.mem.Allocator, base_url: []const u8) !GraphitiIntegration {
        const client = GraphitiClient.init(allocator, base_url);

        // Check if Graphiti service is available
        const enabled = client.healthCheck() catch false;

        return .{
            .client = client,
            .enabled = enabled,
        };
    }

    pub fn deinit(self: *GraphitiIntegration) void {
        self.client.deinit();
    }

    pub fn syncConcept(self: *GraphitiIntegration, concept: []const u8) !void {
        if (!self.enabled) return;

        try self.client.addEpisode(.{
            .content = concept,
            .source = "tui-story",
            .timestamp = null, // Could add current timestamp
        });
    }

    pub fn enhanceRelationships(
        self: *GraphitiIntegration,
        concept: []const u8,
        existing_concepts: []const []const u8
    ) ![]graph.Relationship {
        if (!self.enabled) {
            return &[_]graph.Relationship{}; // Return empty if disabled
        }

        const query = try std.fmt.allocPrint(
            self.client.allocator,
            "Find relationships for: {s}",
            .{concept}
        );
        defer self.client.allocator.free(query);

        const results = try self.client.search(query);
        defer results.deinit(self.client.allocator);

        // Convert Graphiti edges to our Relationship format
        // This allows hybrid operation: LLM + Graphiti insights
        return convertToRelationships(results.edges);
    }
};
```

## Consequences

### Positive

- **Clear separation of concerns**: Zig handles performance-critical TUI, Graphiti handles knowledge graph reasoning
- **Independent scaling**: Services can be scaled independently based on load
- **Type-safe contracts**: JSON schemas provide clear API boundaries
- **No runtime embedding**: Avoid complexity of embedding Python in Zig
- **Gradual adoption**: Can run in hybrid mode (LLM + Graphiti) or fallback to pure LLM
- **Temporal knowledge**: Gain episodic memory and time-based reasoning
- **Production backends**: Leverage mature graph databases (Neo4j, FalkorDB)
- **LLM-powered extraction**: Benefit from Graphiti's entity/relationship extraction
- **Service reusability**: FastAPI service can be used by other applications

### Negative

- **Network overhead**: HTTP calls add latency vs in-process operations
- **Additional infrastructure**: Requires running Python service + graph database
- **Operational complexity**: More services to deploy, monitor, and maintain
- **Dependency on external service**: TUI degraded if Graphiti service unavailable
- **Data consistency**: Need to handle sync between local graph and Graphiti
- **Learning curve**: Team needs to understand Graphiti framework and graph databases

### Neutral

- **Language diversity**: Python service + Zig client is acceptable for microservices architecture
- **Development workflow**: Service can be developed/tested independently
- **Testing**: Can mock HTTP endpoints for unit tests

## Alternatives Considered

### Alternative 1: Direct Neo4j Integration

**Description**: Bypass Graphiti entirely, implement graph operations directly using Neo4j Bolt protocol client in Zig.

```zig
const neo4j = @import("neo4j_client.zig");

pub const KnowledgeGraph = struct {
    db: neo4j.Connection,

    pub fn createEntity(
        self: *KnowledgeGraph,
        name: []const u8,
        entity_type: []const u8
    ) !void {
        const cypher =
            \\CREATE (e:Entity {
            \\  name: $name,
            \\  type: $type,
            \\  created_at: datetime()
            \\})
            \\RETURN e
        ;

        try self.db.execute(cypher, .{
            .name = name,
            .@"type" = entity_type,
        });
    }

    pub fn createRelation(
        self: *KnowledgeGraph,
        from: []const u8,
        to: []const u8,
        rel_type: []const u8
    ) !void {
        const cypher =
            \\MATCH (a:Entity {name: $from}), (b:Entity {name: $to})
            \\CREATE (a)-[r:RELATES {
            \\  type: $rel_type,
            \\  timestamp: datetime()
            \\}]->(b)
            \\RETURN r
        ;

        try self.db.execute(cypher, .{
            .from = from,
            .to = to,
            .rel_type = rel_type,
        });
    }
};
```

**Why Rejected**:
- **Lose Graphiti features**: No LLM-powered entity extraction, episodic reasoning
- **Reinvent the wheel**: Would need to implement temporal logic, embeddings, semantic search
- **Maintenance burden**: Zig Neo4j client + custom graph logic to maintain
- **Limited expertise**: Team would need deep Neo4j/Cypher expertise
- **Cypher complexity**: Complex queries harder in string-based Cypher than Graphiti's API

### Alternative 2: Embedded Python Runtime

**Description**: Embed Python runtime in Zig using CPython C API or PyO3-like bindings.

```zig
// Hypothetical Python embedding
const python = @import("python_embed.zig");

pub fn initGraphiti() !void {
    try python.initialize();
    const graphiti = try python.import("graphiti_core");
    const instance = try graphiti.call("Graphiti", .{
        .neo4j_uri = "bolt://localhost:7687"
    });
    return instance;
}
```

**Why Rejected**:
- **Complex integration**: CPython embedding is notoriously difficult
- **Memory management conflicts**: Zig's allocator vs Python's reference counting
- **Binary size bloat**: Embedding Python runtime significantly increases binary
- **Distribution complexity**: Users need Python dependencies bundled
- **Debugging nightmares**: Stack traces across language boundaries
- **Performance unpredictability**: GIL and runtime overhead in critical path

### Alternative 3: Graphiti as Optional Plugin

**Description**: Make Graphiti integration completely optional via plugin system.

```zig
pub const KnowledgeBackend = union(enum) {
    local: LocalGraph,
    graphiti: GraphitiClient,
    neo4j: Neo4jClient,
};
```

**Why Rejected**:
- **Over-engineering**: Too flexible for current needs
- **Complexity**: Plugin system adds significant architectural overhead
- **Testing burden**: Must test all backend combinations
- **User confusion**: Too many configuration options
- **Better served by**: Strategy 1 (HTTP service) already provides fallback mechanism

### Alternative 4: GraphQL Gateway

**Description**: Use GraphQL instead of REST for richer querying capabilities.

**Why Rejected**:
- **Overkill**: REST API sufficient for current use cases
- **Zig GraphQL clients**: Immature ecosystem
- **Complexity**: GraphQL adds schema coordination overhead
- **Learning curve**: Team would need GraphQL expertise
- **Network efficiency**: Not a bottleneck for this application's scale

## Implementation Plan

### Phase 1: Proof of Concept (Week 1-2)
1. Create minimal FastAPI Graphiti service
2. Implement basic Zig HTTP client
3. Add single endpoint integration (add_episode)
4. Validate end-to-end flow

### Phase 2: Core Integration (Week 3-4)
1. Implement full GraphitiClient in Zig
2. Add search and relationship extraction
3. Integrate with existing AnalysisService
4. Add fallback logic when service unavailable

### Phase 3: Production Readiness (Week 5-6)
1. Add retry logic and error handling
2. Implement connection pooling
3. Add monitoring and health checks
4. Write comprehensive tests
5. Document deployment procedures

### Phase 4: Enhanced Features (Future)
1. Temporal queries (time-based knowledge retrieval)
2. Knowledge graph visualization enhancements
3. Multi-user support via Graphiti
4. Export/import graph snapshots

## Configuration

### Environment Variables

```bash
# Graphiti service configuration
export GRAPHITI_ENABLED=true
export GRAPHITI_BASE_URL="http://localhost:8000"
export GRAPHITI_TIMEOUT=30  # seconds
export GRAPHITI_RETRY_ATTEMPTS=3

# Graph database configuration (for Graphiti service)
export NEO4J_URI="bolt://localhost:7687"
export NEO4J_USER="neo4j"
export NEO4J_PASSWORD="password"

# Fallback behavior
export GRAPHITI_FALLBACK_TO_LLM=true  # Use LLM if Graphiti unavailable
```

## Performance Considerations

- **HTTP latency**: ~10-50ms per request (local network)
- **Graph queries**: Neo4j handles millions of nodes efficiently
- **Caching**: Could add Redis cache layer for frequent queries
- **Batch operations**: Consider batching concept additions
- **Async operations**: Don't block TUI on Graphiti responses

## Security Considerations

- **API authentication**: Add JWT or API key authentication
- **Network encryption**: Use HTTPS/TLS in production
- **Input validation**: Sanitize all inputs on both Zig and Python sides
- **Rate limiting**: Prevent abuse of Graphiti service
- **Database access**: Graphiti service is only client with DB access

## Notes

- **Service-oriented architecture**: Aligns with modern microservices best practices
- **Language strengths**: Zig for systems performance, Python for ML/LLM integration
- **Gradual migration**: Can start with hybrid approach, expand Graphiti usage over time
- **Open source**: Both Graphiti and Neo4j have open-source editions
- **Community**: Graphiti has active development and community support
- **Related ADRs**:
  - ADR-005 (Service Layer Extraction) - Architectural pattern consistency
  - ADR-002 (Mock LLM Fallback) - Similar fallback mechanism pattern

## References

- [Graphiti GitHub](https://github.com/getzep/graphiti)
- [Graphiti Documentation](https://graphiti.zep.ai/)
- [Neo4j Bolt Protocol](https://neo4j.com/docs/bolt/current/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [FalkorDB](https://www.falkordb.com/) - Redis-based graph alternative

## Date

2025-11-21
