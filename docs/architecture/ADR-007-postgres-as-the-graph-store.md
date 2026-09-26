# ADR-007: PostgreSQL as the graph store, and the retirement of Graphiti/Neo4j

## Status

Accepted. Supersedes ADR-006.

## Context

Two things were true at the same time, and neither was written down.

**The graph had no database.** `Vertex` and `Edge` used `Ash.DataLayer.Ets`, so
the graph the TUI draws lived in memory and was gone on restart. `vertex.ex`
nonetheless defined `edge_count` as a raw SQL fragment — a calculation that can
never execute on ETS — which is evidence the resources were authored against a
SQL data layer and then parked.

**The database had no graph.** ADR-006 proposed Graphiti for temporal knowledge
and episodic memory. What was built was `graphiti_service`, a FastAPI process in
front of Neo4j, in which `graphiti_core` is commented out. Its three operations
were:

- `add_episode` — `CREATE (e:Episode {content, source, timestamp})`. One node, no
  relationships, returning `entities_extracted: 0, edges_created: 0` hardcoded.
- `search` — `MATCH (e:Episode) WHERE e.content CONTAINS $query`. A substring
  scan, returning `edges: []` unconditionally.
- `get_relationships` — `return []`.

No traversal, no edges, no pattern matching. Because `edges` was always empty,
`Graphiti.Integration.enhance_relationships/2` folded nothing into the graph on
every call it ever made. The subsystem cost an HTTP hop, a GenServer, a
health-check loop, a second language, a Dockerfile, a Neo4j container and 20
tests, and contributed no relationship to any graph.

The dependency cost was not free either: `graphiti-core` pulls `openai>=1.91`
and `neo4j>=5.26`, and a Dependabot bump of it against a stale `neo4j==5.14.0`
pin left `requirements.txt` unresolvable by pip.

## Decision

Retire Graphiti and Neo4j. Move the graph itself into PostgreSQL via
`AshPostgres.DataLayer`, and delete `graphiti_service` entirely.

The deduplication rule moves into the schema with it. `add_relationship`
previously read for an existing edge inside a change function and then decided —
two round trips with a window between them, so two concurrent analyses of the
same pair could both observe "no existing edge" and both insert. It is now one
statement:

```elixir
upsert? true
upsert_identity :unique_relationship
upsert_fields [:certainty, :description]
upsert_condition expr(certainty < upsert_conflict(:certainty))
```

against a unique index on `(from_vertex_id, to_vertex_id, relation_type)`. The
self-loop rule likewise becomes a check constraint. Both are tested by inserting
through raw SQL, bypassing Ash, because the claim is about what the graph can
contain rather than about what one action checks.

## Consequences

### Positive

- The graph persists. This is the change ADR-006 was reaching for.
- `edge_count` works, as two aggregates the data layer compiles into SQL.
- One language. No service boundary, no Dockerfile, no second CI job.
- A duplicate edge and a self-loop are unrepresentable rather than rejected
  after the fact, and are no longer subject to a race.
- `add_relationship` returns `{:ok, edge}` when it updates in place. It used to
  signal "updated" by returning an *error*, which the caller could not
  distinguish from a real failure — so every certainty upgrade was logged as a
  failure and dropped from the returned relationships.
- The suite went from 65 tests / 16 failures / 38s to 47 tests / 0 failures /
  0.7s. The drop in count is the 20 Graphiti tests leaving with the subsystem.

### Negative

- Temporal knowledge graphs and automatic entity extraction are now out of
  scope. Nothing is lost that was working, but the *intent* of ADR-006 is
  withdrawn rather than deferred, and should be reopened deliberately if wanted.
- Running the application now requires PostgreSQL where it previously required
  nothing. `docker compose up -d` covers it.
- Deep traversal would need recursive CTEs. At 1-hop queries and TUI-scale
  graphs this is not a constraint we are near.

### Neutral

- The LLM relationship extraction path is untouched. It was always the thing
  that actually produced relationships.
- The nine relation types, certainty semantics and the TUI are unchanged.

## Alternatives Considered

### Alternative 1: Port the Neo4j wrapper to PostgreSQL

Keep `graphiti_service`, swap Cypher for SQL. Rejected: it would migrate a
component whose entire contribution is `[]`, and keep the second language, the
HTTP hop and the service boundary to do it.

### Alternative 2: Actually implement Graphiti

Uncomment it and build what ADR-006 proposed. Rejected for now, not forever: it
is a real capability and a real library, but it needs a graph backend, it does
not address the fact that the primary graph has no persistence, and it has sat
at "TODO: implement when available" for the life of the repository while the
library was on PyPI the whole time. That is not a deferred integration; it is a
decision nobody made. Reopen it as its own ADR if the capability is wanted.

### Alternative 3: Keep ETS and add snapshotting

Serialize the ETS tables periodically. Rejected: it reimplements durability,
concurrency control and constraints that PostgreSQL already has, and the
resources were written against SQL to begin with.

## Notes

- Supersedes [ADR-006](./ADR-006-graphiti-knowledge-graph-integration.md), which
  never moved past Proposed.
- The unique index and check constraint follow the estate's P5 ruling — make the
  illegal state unrepresentable, not merely rejected — recorded in
  `larsbx/cross-pollinated`, where `coop_substrate`, `spruce` and `meta_test`
  each reached it independently.

## Date

2026-09-19
