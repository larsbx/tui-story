# tui-story Remediation Specification

**Status:** PROPOSED-FOR-EXECUTION  
**Date:** 2026-09-08  
**Repository:** `larsbx/tui-story`  
**Baseline:** `27af798d14ab6fc303cdf089cb3225bc84e34fe5`  
**Target:** restore one executable architecture, one source of truth, one truthful CI pipeline, and a bounded agent-execution surface.

---

## 0. Executive decision

The repository SHALL be remediated around the Elixir/Ash application as the primary application runtime.

The normative architecture after remediation is:

```text
Ratatouille TUI
      |
      v
Elixir/Ash domain  <---- canonical application state
      |
      +---- LLM adapter
      |
      +---- Graphiti adapter ----> Graphiti/FastAPI ----> Neo4j
                                  derived semantic index
```

The following decisions are binding for this remediation:

1. **Elixir/Ash is the application authority.** Legacy Zig implementation references are historical only.
2. **Canonical graph data must be persistent.** ETS may remain available for tests or ephemeral development, but SHALL NOT be the production source of truth.
3. **Graphiti/Neo4j is a derived semantic/temporal index, not the canonical graph store.** Loss or rebuild of Graphiti must not destroy canonical application state.
4. **The TUI, HTTP/API surfaces, background analysis, and reset flows must all use the same domain operations.** No parallel mutation paths.
5. **`auto_agent/` is not part of the trusted runtime.** It SHALL be quarantined or moved to a separate experimental repository before production release.
6. **CI is the executable truth.** Documentation may not claim a subsystem is complete unless CI exercises the relevant contract.

---

## 1. Severity model

- **P0 — Release blocker:** repository cannot be considered buildable, correct, or safely deployable.
- **P1 — Integrity/security blocker:** application may run but can corrupt state, violate trust boundaries, or misrepresent guarantees.
- **P2 — Hardening/maintainability:** required before declaring production-ready.

No P1 or P2 work may mask an unresolved P0.

---

## 2. Required invariants

### INV-1 — One build truth

The default CI pipeline SHALL build and test the current Elixir/Python implementation and SHALL contain no required Zig build steps after the completed migration.

**Acceptance:** a clean checkout passes CI without any `src/*.zig`, `tests/*.zig`, `build.zig`, or `build.zig.zon` files.

### INV-2 — Cross-service contract agreement

The Elixir Graphiti client and bundled FastAPI service SHALL agree on HTTP method, path, request shape, response shape, and accepted success status for every supported operation.

At minimum:

- `GET /health`
- `POST /episodes` -> success includes HTTP `201`
- `POST /search`

**Acceptance:** a contract test boots the real bundled FastAPI service and calls it through the real Elixir client.

### INV-3 — No atom creation from untrusted strings

No LLM output, HTTP payload, environment variable, MCP payload, Graphiti response, or user input may flow to `String.to_atom/1`.

Relationship types SHALL be parsed through an explicit finite mapping.

**Acceptance:** unknown types return a typed validation error or a documented bounded fallback without creating atoms.

### INV-4 — Atomic edge identity

An edge is uniquely identified by:

```text
(from_vertex_id, to_vertex_id, relation_type)
```

Creation/upgrading SHALL be atomic from the caller's perspective.

For an existing edge:

- higher certainty -> update existing edge and return success;
- equal/lower certainty -> return existing edge or a typed no-op success;
- never represent a successful update as `{:error, ...}`.

**Acceptance:** concurrency test proves duplicate edges cannot be created by simultaneous analyses.

### INV-5 — Domain-owned reset

All destructive reset behavior SHALL pass through exactly one domain service/action.

Edges must be removed before vertices or deleted transactionally with referential integrity.

**Acceptance:** reset followed by render, graph query, and re-add succeeds without orphaned references.

### INV-6 — Failure is data, not an uncontrolled crash

Expected external failures SHALL return typed results rather than relying on destructive pattern matches.

Examples:

- LLM timeout
- LLM parse failure
- Graphiti unavailable
- invalid relationship type
- persistence failure

Background analysis SHALL run under a supervised, non-linked execution boundary from the TUI process.

### INV-7 — Canonical persistence

Production canonical Vertex/Edge state SHALL use a persistent Ash data layer, preferably AshPostgres/PostgreSQL.

ETS SHALL be scoped to test/dev-only use unless explicitly configured as ephemeral mode.

### INV-8 — Derived Graphiti state

Graphiti synchronization failure SHALL NOT roll back a successfully committed canonical graph mutation unless an explicit transactional mode is introduced later.

The system SHALL be able to re-project canonical graph state into Graphiti.

### INV-9 — Bounded self-modification

No production process may:

- overwrite its own source,
- compile model-generated code in-process,
- run `git add .`,
- commit arbitrary worktree changes,
- hot-load model-generated modules.

Any future code-evolution workflow SHALL use an isolated worktree/container and explicit promotion gate.

### INV-10 — Documentation truthfulness

README, version metadata, architecture ADRs, MCP status, and implementation status SHALL match executable reality.

A feature labelled "complete" must have a CI-enforced test or contract proving its claimed boundary.

---

## 3. P0 remediation

### P0.1 Replace obsolete Zig CI

**File:** `.github/workflows/ci.yml`

Replace the current Zig workflow with jobs equivalent to:

#### `elixir`

- setup supported OTP + Elixir versions
- `mix deps.get`
- `mix deps.compile`
- `mix format --check-formatted`
- `mix compile --warnings-as-errors`
- `mix test`

Working directory: `semantic_graph/`.

#### `elixir-static`

- `mix credo --strict`
- Dialyzer, either required immediately or introduced as an allowed-failure bootstrap with a dated issue and then promoted to required.

#### `python`

Working directory: `graphiti_service/`.

- create virtualenv or use setup-python
- install `requirements.txt`
- syntax/import test
- pytest once tests are added

#### `contract`

- boot Neo4j + Graphiti service using service containers or Docker Compose
- wait for `/health`
- run Elixir Graphiti contract tests against the real service

#### `docs`

- markdown lint/link checks only against paths that exist
- preserve mdBook only if the current book builds from the current source tree

Remove all required references to Zig setup/build/test.

### P0.2 Repair Graphiti protocol mismatch

**Files:**

- `semantic_graph/lib/semantic_graph/graphiti/client.ex`
- `semantic_graph/test/semantic_graph/graphiti/client_test.exs`
- `graphiti_service/main.py`
- Graphiti integration tests

Required contract:

```text
GET  /health
POST /episodes -> 201
POST /search   -> 200
```

The Elixir client SHALL accept the FastAPI service's documented success code for `/episodes`.

`search/2` SHALL send a JSON POST body compatible with `SearchQuery`, not query parameters on GET.

Mocks SHALL mirror the real service contract exactly.

### P0.3 Restore compile correctness

**Files:**

- `semantic_graph/lib/semantic_graph/graph_api.ex`
- `semantic_graph/mix.exs`
- application startup modules as needed

Required changes:

1. Ensure Ash query macro usage is valid (`require Ash.Query` where required, or use supported query construction consistently).
2. Add Finch as an explicit dependency if `SemanticGraph.Application` starts Finch; otherwise remove the Finch child and use the chosen HTTP stack consistently.
3. Make `mix compile --warnings-as-errors` a required CI gate.

### P0.4 Fix reset corruption

**Files:**

- `semantic_graph/lib/semantic_graph/tui.ex`
- `semantic_graph/lib/semantic_graph/graph_api.ex`
- reset tests

The TUI SHALL call the domain reset operation and SHALL NOT independently destroy vertices.

Add tests for:

1. create vertices and edges;
2. reset;
3. assert zero vertices and zero edges;
4. render graph/help state without exception;
5. add a new vertex after reset.

---

## 4. P1 remediation

### P1.1 Replace dynamic atom conversion

**Files:**

- `semantic_graph/lib/semantic_graph/llm/client.ex`
- `semantic_graph/config/runtime.exs`

Create one bounded parser for provider and relationship types.

Example shape:

```elixir
@relationship_types %{
  "contradictory" => :contradictory,
  "implicative" => :implicative,
  "hierarchical" => :hierarchical,
  "evolutionary" => :evolutionary,
  "analogous" => :analogous,
  "synonymous" => :synonymous,
  "antonymous" => :antonymous,
  "part_whole" => :part_whole,
  "causal" => :causal
}
```

Unknown external values SHALL NOT create atoms.

### P1.2 Replace edge dedup side effects with upsert semantics

**Files:**

- `semantic_graph/lib/semantic_graph/resources/edge.ex`
- persistence migration/schema
- resource tests

Remove `Ash.update()` from inside the create changeset callback.

Implement an identity/unique constraint over `(from_vertex_id, to_vertex_id, relation_type)` and a supported atomic upsert/update path.

The public API SHALL return success after either creation or certainty upgrade.

Add a concurrent test with multiple tasks attempting the same edge.

### P1.3 Make analysis orchestration total

**File:** `semantic_graph/lib/semantic_graph/analysis/service.ex`

Replace destructive matches such as:

```elixir
{:ok, value} = external_call()
```

with explicit result propagation.

Define a bounded error algebra, e.g.:

```text
:invalid_input
:llm_unavailable
:llm_invalid_response
:persistence_failed
:graphiti_unavailable   # normally warning/non-fatal
```

Actual names may differ, but callers must be able to distinguish expected failures.

### P1.4 Supervise analysis work

Introduce `Task.Supervisor` or an equivalent supervised worker under `SemanticGraph.Application`.

The TUI SHALL use a non-linked task boundary and handle:

- success,
- typed failure,
- worker exit,
- timeout,
- cancellation.

Cancellation SHALL not leave a partially inconsistent canonical graph.

### P1.5 Canonical persistent store

Migrate production Vertex/Edge resources from `Ash.DataLayer.Ets` to a persistent Ash data layer.

Preferred implementation:

```text
AshPostgres + PostgreSQL
```

Required properties:

- database-enforced edge uniqueness;
- transactional reset;
- migrations committed to repo;
- test isolation;
- documented dev setup.

Graphiti/Neo4j remains derived.

### P1.6 Secure local service boundaries

**Files:**

- `docker-compose.yml`
- `.env.example` / `.env.docker`
- Graphiti deployment configuration

Required changes:

- no hard-coded production-like Neo4j password;
- use environment/secret injection;
- bind development ports to `127.0.0.1` unless exposure is explicitly requested;
- avoid publishing Bolt/Neo4j browser ports when not needed;
- document Graphiti service as unauthenticated local-development-only until authentication is implemented;
- replace permissive production CORS configuration.

---

## 5. P2 remediation

### P2.1 Quarantine `auto_agent`

Preferred: move `auto_agent/` to a separate experimental repository.

Acceptable interim: move under an explicitly non-production path such as `experiments/auto_agent/`, exclude it from release builds, and add a security note.

Any future execution design must be:

```text
proposal
  -> isolated worktree/container
  -> compile
  -> unit/integration tests
  -> static/security checks
  -> diff/path allowlist
  -> human or policy promotion
  -> signed commit
```

No in-process compilation or hot loading of model-generated source in the production VM.

### P2.2 Reconcile documentation and versioning

At minimum update:

- `README.md`
- `semantic_graph/mix.exs`
- `docs/project/ELIXIR_IMPLEMENTATION_STATUS.md`
- architecture ADR index and stale Zig ADR status
- MCP documentation/status

Remove executable Zig commands from active documentation.

Choose exactly one release version source and derive displayed versions from it where practical.

### P2.3 Formal verification enforcement

The repository currently contains TLA+ artifacts. Either:

1. run TLC/model checking in CI and publish the checked configurations; or
2. relabel the artifacts as formal specifications/models rather than claiming enforced verification.

Preferred path: add a `formal` CI job using pinned tooling and bounded model configurations.

### P2.4 Repository governance

After remediation:

- create/use stable `main` as default branch;
- protect `main`;
- require passing CI before merge;
- require review for release-affecting changes;
- prune stale agent-generated branches after confirming no unique work is lost;
- require signed release tags and preferably signed commits on protected/release branches.

---

## 6. Required tests

The remediation is incomplete until the following tests exist and pass.

### Domain

- vertex input trim/validation
- finite relationship type parser
- self-loop rejection
- edge certainty bounds
- atomic edge create/upsert
- concurrent duplicate-edge prevention
- graph reset transactional behavior

### Analysis

- first concept
- multi-concept analysis
- invalid LLM response
- timeout/network failure
- Graphiti unavailable but canonical write succeeds where intended
- duplicate LLM + Graphiti relationship merged deterministically
- cancellation behavior

### Graphiti contract

Using the real FastAPI service:

- health check
- episode creation accepts `201`
- search uses POST JSON body
- malformed request handling
- service unavailable behavior

### TUI

- reset delegates to domain
- analysis success transition
- analysis failure transition
- task exit transition
- cancel transition
- render after reset

### Persistence

- restart process/app and canonical graph survives
- uniqueness enforced by datastore
- migration boots from empty database

### Security regression

- unknown LLM relationship type does not increase atom count through dynamic creation path
- unknown provider is rejected or mapped without `String.to_atom/1`
- production config cannot silently use hard-coded Neo4j credentials

---

## 7. CI release gate

A release candidate SHALL require all of:

```text
[PASS] Elixir format
[PASS] Elixir compile --warnings-as-errors
[PASS] ExUnit
[PASS] Credo
[PASS] Python tests/import checks
[PASS] Real Elixir <-> Graphiti contract test
[PASS] Documentation checks
[PASS] Formal model job, if verification is claimed
[PASS] No tracked secrets/default production credentials
```

No documentation-only success claim may substitute for a failing or absent executable gate.

---

## 8. Execution order for coding agents

Coding agents SHALL execute in this order and keep each step independently reviewable:

1. CI rewrite and compile restoration.
2. Graphiti HTTP contract repair + real contract test.
3. Dynamic atom removal.
4. Reset centralization.
5. Edge identity/upsert correction.
6. Analysis result/error refactor.
7. Supervised task boundary.
8. Persistent canonical store migration.
9. Docker/network hardening.
10. `auto_agent` quarantine.
11. Documentation/version reconciliation.
12. Formal CI and repository governance.

Each step SHALL include tests in the same commit/PR as the behavior change.

Do not combine persistence migration, agent quarantine, and UI refactoring into one large patch unless mechanically necessary.

---

## 9. Definition of done

The remediation is complete only when all statements below are true:

- A fresh clone on the default branch passes CI.
- CI tests the Elixir/Python implementation rather than deleted Zig code.
- The real Elixir Graphiti client interoperates with the bundled FastAPI service.
- No untrusted string is converted with `String.to_atom/1`.
- Edge identity is datastore-enforced and concurrency-safe.
- Reset cannot orphan edges.
- TUI analysis failures cannot crash the TUI process through task linkage.
- Canonical graph state survives application restart.
- Graphiti can be unavailable without becoming the hidden source of truth.
- The production runtime cannot self-modify source or commit arbitrary repository contents.
- README/status/version claims match the executable system.
- The protected default branch represents the sole integrated source of truth.

---

## 10. Non-goals

This remediation does **not** add new semantic relationship types, new MCP features, new UI features, autonomous code evolution, or new LLM providers.

Feature expansion resumes only after P0 and P1 acceptance criteria are green.
