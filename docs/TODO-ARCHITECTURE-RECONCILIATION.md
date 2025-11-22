# TODO: Architecture Reconciliation - Elixir/Ash vs Graphiti Integration

**Date**: 2025-11-22
**Status**: Decision Required
**Related Documents**:
- `docs/ELIXIR_ASH_FEASIBILITY.md` - Elixir/Ash + Ratatouille port analysis
- `docs/architecture/ADR-006-graphiti-knowledge-graph-integration.md` - Graphiti temporal graph integration

---

## Executive Summary: Two Divergent Architectural Paths

We have two comprehensive architectural proposals that need reconciliation:

| Aspect | **Path A: Elixir/Ash Port** | **Path B: Zig + Graphiti** |
|--------|---------------------------|---------------------------|
| **TUI** | Ratatouille (Elixir) | libvaxis (Zig - existing) |
| **Domain Logic** | Ash Resources (Elixir) | Current Zig implementation |
| **Graph Storage** | ETS (in-memory) | Neo4j/FalkorDB (persistent) |
| **Temporal Features** | Not included | ✅ Episodic memory via Graphiti |
| **Concurrency** | OTP (built-in) | Manual mutex management |
| **Timeline** | 5-7 weeks full rewrite | 2-6 weeks incremental addition |
| **Risk** | Medium (full port) | Low (additive enhancement) |

**Critical Question**: Which path do we take, or can we combine them?

---

## Option 1: Pure Elixir/Ash (Feasibility Study Path)

### Overview
Complete port to Elixir/Ash + Ratatouille, using ETS for graph storage.

### Advantages
- ✅ Better concurrency model (OTP)
- ✅ Cleaner architecture (declarative Ash resources)
- ✅ Terminal UI maintained via Ratatouille
- ✅ Easier testing and maintainability
- ✅ Single language/ecosystem

### Disadvantages
- ❌ **No temporal/episodic knowledge** (loses ADR-006 benefits)
- ❌ In-memory only (no Neo4j persistence)
- ❌ Full rewrite risk (5-7 weeks)
- ❌ Loses existing Zig performance optimizations
- ❌ Team needs Elixir expertise

### TODOs if choosing this path:

#### [ ] Critical: Add Temporal Graph Capabilities to Elixir Design

**Priority**: HIGH
**Effort**: 2-3 weeks (additional to 5-7 week timeline)

Create `docs/ELIXIR_ASH_TEMPORAL_EXTENSION.md` addressing:

1. **Temporal Data Modeling in Ash**
   ```elixir
   # How to add temporal attributes to Vertex/Edge resources
   defmodule GraphAPI.Resources.Vertex do
     attributes do
       attribute :created_at, :utc_datetime_usec
       attribute :last_modified_at, :utc_datetime_usec
       attribute :temporal_context, :string  # Episode/session context
     end
   end
   ```

2. **Integrate Ecto for Persistent Storage**
   - Replace ETS with PostgreSQL + Ecto
   - Use TimescaleDB extension for temporal queries
   - Maintain in-memory cache for performance

3. **Add Episodic Memory Module**
   ```elixir
   defmodule GraphAPI.EpisodicMemory do
     # Track knowledge evolution over time
     # Similar to Graphiti's episode system
   end
   ```

4. **Consider Hybrid: Elixir + Graphiti Service**
   - Elixir/Ash for domain logic and TUI
   - Graphiti service for temporal graph features
   - Tesla HTTP client to Graphiti (similar to ADR-006 pattern)

**Action Items**:
- [ ] Research Elixir temporal graph libraries (e.g., `bolt_sips` for Neo4j)
- [ ] Design Ash resource schema with temporal attributes
- [ ] Prototype PostgreSQL + TimescaleDB integration
- [ ] Compare Elixir-native temporal graph vs Graphiti service approach

---

## Option 2: Zig + Graphiti Integration (ADR-006 Path)

### Overview
Keep current Zig implementation, add Graphiti service for temporal knowledge.

### Advantages
- ✅ **Temporal/episodic memory** (ADR-006 core benefit)
- ✅ Incremental enhancement (lower risk)
- ✅ Proven Zig TUI performance
- ✅ Leverages existing codebase
- ✅ Graphiti's LLM-powered entity extraction

### Disadvantages
- ❌ Manual mutex management remains
- ❌ Less scalable for concurrent MCP connections
- ❌ Multi-language stack (Zig + Python)
- ❌ Operational complexity (multiple services)

### TODOs if choosing this path:

#### [ ] Implement ADR-006 as Specified

**Priority**: MEDIUM
**Effort**: As per ADR-006 timeline (6 weeks)

Follow ADR-006 implementation plan:

**Phase 1: Proof of Concept (Week 1-2)**
- [ ] Create FastAPI Graphiti service (ADR-006 lines 48-114)
- [ ] Implement Zig GraphitiClient (ADR-006 lines 118-272)
- [ ] Test `/episodes` endpoint integration
- [ ] Validate health check mechanism

**Phase 2: Core Integration (Week 3-4)**
- [ ] Complete GraphitiClient.search() implementation
- [ ] Integrate with AnalysisService (ADR-006 lines 276-336)
- [ ] Add fallback logic when Graphiti unavailable
- [ ] Environment variable configuration (ADR-006 lines 517-532)

**Phase 3: Production Readiness (Week 5-6)**
- [ ] Add retry logic with exponential backoff
- [ ] Implement connection pooling
- [ ] Add monitoring/health checks
- [ ] Write comprehensive tests
- [ ] Document deployment procedures

**Additional TODOs**:
- [ ] Set up Neo4j or FalkorDB instance
- [ ] Configure Graphiti with chosen backend
- [ ] Create Docker Compose for local development
- [ ] Add systemd service files for production

---

## Option 3: Hybrid Architecture (RECOMMENDED)

### Overview
**Best of both worlds**: Elixir/Ash domain layer + Graphiti temporal service + Ratatouille TUI

### Architecture

```
┌─────────────────────────────────────────────────┐
│         Elixir Application (Core)               │
│                                                 │
│  ┌──────────────┐         ┌─────────────────┐  │
│  │ Ratatouille  │         │   Phoenix HTTP  │  │
│  │     TUI      │         │   MCP Server    │  │
│  └──────┬───────┘         └────────┬────────┘  │
│         │                          │           │
│         ▼                          ▼           │
│  ┌──────────────────────────────────────────┐  │
│  │        Ash Resources Layer               │  │
│  │  - Vertex, Edge, Graph resources        │  │
│  │  - Custom actions (analyze_idea, etc.)  │  │
│  └──────────┬──────────────┬────────────────┘  │
│             │              │                    │
│    ┌────────▼──────┐  ┌───▼──────────┐        │
│    │  ETS Cache    │  │ Graphiti     │        │
│    │  (Fast reads) │  │ HTTP Client  │        │
│    └───────────────┘  └───┬──────────┘        │
└────────────────────────────┼───────────────────┘
                             │ HTTP/JSON
                    ┌────────▼────────┐
                    │ Graphiti Service│
                    │   (Python)      │
                    │  - FastAPI      │
                    │  - Episodic mem │
                    └────────┬────────┘
                             │
                      ┌──────▼──────┐
                      │   Neo4j     │
                      │  or FalkorDB│
                      └─────────────┘
```

### Why This is Best

1. **Elixir/Ash Benefits**: Concurrency, clean architecture, maintainability
2. **Graphiti Benefits**: Temporal knowledge, episodic memory, LLM entity extraction
3. **Ratatouille**: Terminal UI experience maintained
4. **Separation of Concerns**: Elixir for domain logic, Graphiti for temporal graph
5. **Incremental Migration**: Can start with Elixir core, add Graphiti later (or vice versa)

### Critical TODOs for Hybrid Approach

#### [ ] Phase 1: Elixir Core with Mock Temporal (Weeks 1-4)

**Goal**: Port core functionality to Elixir/Ash without Graphiti dependency

- [ ] Set up Phoenix + Ash project structure
- [ ] Define Vertex, Edge resources (with temporal attributes for future)
- [ ] Implement custom actions: `analyze_new_idea`, `get_graph`, etc.
- [ ] Build Ratatouille TUI (all 4 modes)
- [ ] Add ETS cache for fast local operations
- [ ] Create mock temporal service for testing

**Deliverable**: Working Elixir app with Ratatouille TUI, no Graphiti yet

#### [ ] Phase 2: Graphiti Service Development (Weeks 5-6, Parallel)

**Goal**: Build Graphiti service per ADR-006, independent of Elixir app

- [ ] Implement FastAPI Graphiti service (ADR-006 spec)
- [ ] Set up Neo4j or FalkorDB backend
- [ ] Add episode ingestion endpoint
- [ ] Add temporal search endpoint
- [ ] Add entity/relationship extraction
- [ ] Containerize with Docker

**Deliverable**: Standalone Graphiti service, testable independently

#### [ ] Phase 3: Integration (Weeks 7-8)

**Goal**: Connect Elixir app to Graphiti service

- [ ] Create `GraphAPI.Graphiti.Client` module (Tesla-based)
  ```elixir
  defmodule GraphAPI.Graphiti.Client do
    use Tesla

    plug Tesla.Middleware.BaseUrl, graphiti_base_url()
    plug Tesla.Middleware.JSON
    plug Tesla.Middleware.Retry

    def add_episode(content, metadata) do
      post("/episodes", %{content: content, metadata: metadata})
    end

    def temporal_search(query, time_range) do
      get("/search", query: [q: query, from: time_range.from, to: time_range.to])
    end
  end
  ```

- [ ] Enhance `analyze_new_idea` action to use both:
  - ETS for fast local relationship lookup
  - Graphiti for temporal context and historical patterns

- [ ] Add configuration for hybrid mode:
  ```elixir
  config :graph_api, :knowledge_backend,
    local: [enabled: true, cache: :ets],
    graphiti: [
      enabled: System.get_env("GRAPHITI_ENABLED", "true"),
      base_url: System.get_env("GRAPHITI_URL", "http://localhost:8000"),
      timeout: 30_000
    ]
  ```

- [ ] Implement fallback logic:
  - If Graphiti unavailable → pure local ETS mode
  - If Graphiti available → hybrid (enrich local results with temporal insights)

- [ ] Add temporal query features to TUI:
  - New mode: "Temporal View" showing knowledge evolution
  - Timeline navigation (arrow keys to move through time)
  - "When was this relationship first discovered?" queries

**Deliverable**: Fully integrated Elixir + Graphiti system

#### [ ] Phase 4: Production Hardening (Week 9)

- [ ] Load testing (concurrent MCP connections + Graphiti queries)
- [ ] Monitoring setup (Prometheus metrics for both Elixir and Graphiti)
- [ ] Circuit breaker for Graphiti service failures
- [ ] Deployment automation (Docker Compose, Kubernetes manifests)
- [ ] Documentation (deployment guide, architecture diagrams)

**Deliverable**: Production-ready hybrid system

---

## Detailed Comparison: Features Matrix

| Feature | Zig Current | Elixir/Ash Only | Zig + Graphiti | **Elixir + Graphiti (Hybrid)** |
|---------|------------|-----------------|----------------|--------------------------------|
| **TUI Performance** | ✅ Excellent | ✅ Good (Ratatouille) | ✅ Excellent | ✅ Good (Ratatouille) |
| **Concurrency** | ⚠️ Manual mutex | ✅ OTP native | ⚠️ Manual mutex | ✅ OTP native |
| **Temporal Knowledge** | ❌ None | ❌ None | ✅ Graphiti | ✅ Graphiti |
| **Episodic Memory** | ❌ None | ❌ None | ✅ Graphiti | ✅ Graphiti |
| **Persistent Graph** | ⚠️ JSON only | ⚠️ ETS only | ✅ Neo4j | ✅ Neo4j |
| **LLM Entity Extraction** | ⚠️ Manual | ⚠️ Manual | ✅ Graphiti | ✅ Graphiti |
| **MCP HTTP Scaling** | ⚠️ Limited | ✅ Excellent | ⚠️ Limited | ✅ Excellent |
| **Code Maintainability** | ⚠️ Manual memory | ✅ Declarative | ⚠️ Manual memory | ✅ Declarative |
| **Deployment Complexity** | ✅ Single binary | ✅ Single app | ⚠️ Zig + Python + DB | ⚠️ Elixir + Python + DB |
| **Development Timeline** | N/A (current) | 5-7 weeks | 6 weeks | **8-9 weeks** |
| **Risk Level** | N/A | Medium (full rewrite) | Low (additive) | **Medium-Low** |

**Hybrid Wins**: 8/10 categories marked best-in-class ✅

---

## Decision Framework

### Choose **Pure Elixir/Ash** (Option 1) if:
- [ ] Temporal/episodic features are NOT critical
- [ ] Team has strong Elixir expertise or time to learn
- [ ] In-memory graph storage is sufficient (no persistence requirement)
- [ ] Want single-language codebase simplicity
- [ ] 5-7 week timeline is acceptable

### Choose **Zig + Graphiti** (Option 2) if:
- [ ] Must keep existing Zig codebase (team expertise, investment)
- [ ] Temporal/episodic memory is CRITICAL requirement
- [ ] Lower risk tolerance (incremental enhancement preferred)
- [ ] Performance is absolutely paramount
- [ ] Team comfortable with multi-language stack

### Choose **Hybrid Elixir + Graphiti** (Option 3) if: ⭐ RECOMMENDED
- [x] Want BOTH concurrency benefits (Elixir) AND temporal features (Graphiti)
- [x] Building for production scale (many concurrent MCP users)
- [x] Willing to accept 8-9 week timeline
- [x] Team can manage multi-service architecture
- [x] Want best long-term architecture despite higher initial complexity

---

## Immediate Next Steps (This Week)

### [ ] Critical Decision: Stakeholder Alignment

**Owner**: Product/Tech Lead
**Deadline**: This week

- [ ] Schedule architecture review meeting
- [ ] Present all three options with trade-offs
- [ ] Gather input on:
  - Temporal knowledge importance (is Graphiti critical?)
  - Team Elixir expertise/willingness to learn
  - Timeline constraints (5-7 weeks vs 8-9 weeks acceptable?)
  - Operational complexity tolerance (single app vs microservices)

**Decision Artifacts**:
- [ ] Create `docs/architecture/ADR-007-final-architecture-decision.md`
- [ ] Update project roadmap with chosen path
- [ ] Assign engineering resources based on decision

### [ ] Prototype Validation (Regardless of Path)

**Goal**: De-risk the decision with working code

**If leaning Elixir/Ash**:
- [ ] 2-day spike: Build minimal Ash resource + Ratatouille TUI
- [ ] Validate Ratatouille can match libvaxis UX quality
- [ ] Test Ash custom actions for graph operations

**If leaning Graphiti**:
- [ ] 2-day spike: Run Graphiti locally with sample data
- [ ] Test temporal query performance
- [ ] Validate entity extraction quality

**If leaning Hybrid**:
- [ ] Do both spikes above in parallel (4 developer-days total)
- [ ] Test Tesla HTTP client → Graphiti integration

### [ ] Documentation Cleanup

- [ ] Mark `ELIXIR_ASH_FEASIBILITY.md` with decision status
- [ ] Mark `ADR-006` with decision status
- [ ] Create migration path document based on chosen option

---

## Risk Mitigation Strategies

### For Elixir Port Risk

**Risk**: Full rewrite fails, lose 5-7 weeks of effort

**Mitigation**:
- [ ] Implement feature flags to run old Zig code in parallel during migration
- [ ] Incremental cutover: Port MCP server first, TUI later (or vice versa)
- [ ] Set "go/no-go" checkpoints at weeks 2, 4, 6

### For Graphiti Integration Risk

**Risk**: Graphiti service becomes bottleneck or single point of failure

**Mitigation**:
- [ ] Implement robust fallback to local graph when Graphiti down
- [ ] Add circuit breaker pattern (stop hitting Graphiti after N failures)
- [ ] Consider Graphiti as enhancement, not requirement

### For Hybrid Complexity Risk

**Risk**: Managing Elixir + Python + Neo4j is operationally complex

**Mitigation**:
- [ ] Containerize everything (Docker Compose for dev, K8s for prod)
- [ ] Comprehensive monitoring from day 1 (Prometheus + Grafana)
- [ ] Automated deployment scripts
- [ ] Runbooks for common failure scenarios

---

## Success Criteria

Define success metrics for chosen path:

### Performance Metrics
- [ ] TUI render latency < 50ms (Ratatouille or libvaxis)
- [ ] MCP HTTP server handles > 100 concurrent connections
- [ ] Graph query response time < 100ms (local) or < 500ms (with Graphiti)
- [ ] LLM relationship analysis < 30s end-to-end

### Functionality Metrics
- [ ] All current Zig features ported/working
- [ ] Temporal queries functional (if using Graphiti)
- [ ] MCP protocol 100% compliant
- [ ] Zero data loss during migration (if applicable)

### Quality Metrics
- [ ] Test coverage > 80%
- [ ] Zero critical bugs in production first month
- [ ] Documentation complete for deployment + development

---

## Open Questions for Discussion

1. **Timeline Priority**: Is 5-7 weeks (Elixir) acceptable vs 6 weeks (Graphiti) vs 8-9 weeks (Hybrid)?

2. **Temporal Features**: How critical is episodic/temporal knowledge? Is it nice-to-have or core requirement?

3. **Team Capacity**: Do we have Elixir developers available? Python for Graphiti?

4. **Operational Constraints**: Can we run multi-service architecture (Elixir + Graphiti + Neo4j)?

5. **Migration Risk**: Full rewrite (Elixir) vs incremental (Graphiti) - which risk profile fits better?

6. **Long-term Vision**: Where do we see this project in 1 year? 3 years? Does that inform architecture choice?

---

## Recommendation

**I recommend Option 3: Hybrid Elixir/Ash + Graphiti** because:

1. ✅ **Best Technical Architecture**: Combines OTP concurrency + temporal graph capabilities
2. ✅ **Future-Proof**: Scales to multiple concurrent users AND rich knowledge features
3. ✅ **Separation of Concerns**: Elixir domain layer is clean, Graphiti handles complex temporal logic
4. ✅ **Incremental Path**: Can build Elixir core first, add Graphiti later if needed
5. ✅ **Terminal UI Maintained**: Ratatouille proven viable in feasibility study
6. ⚠️ **Acceptable Trade-off**: 8-9 week timeline and operational complexity worthwhile for long-term benefits

**Alternative Recommendation**: If timeline is critical constraint → Start with **Option 2 (Zig + Graphiti)** as lower-risk path, revisit Elixir port in 6 months after Graphiti integration proven successful.

---

## Action Items Summary

**This Week**:
- [ ] Schedule architecture decision meeting
- [ ] Run 2-day prototyping spikes (Ratatouille + Graphiti)
- [ ] Decide on Option 1, 2, or 3

**Next Week** (if Option 3 chosen):
- [ ] Create detailed project plan with milestones
- [ ] Set up development environment (Elixir + Python)
- [ ] Create feature flags for incremental migration
- [ ] Begin Phase 1: Elixir Core Development

**Ongoing**:
- [ ] Weekly architecture review meetings
- [ ] Go/no-go checkpoints every 2 weeks
- [ ] Update this document as decisions are made

---

**Last Updated**: 2025-11-22
**Next Review**: After architecture decision meeting
**Owner**: TBD (assign after stakeholder meeting)
