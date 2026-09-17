<!--
Derived from templates/docs/AGENTS.md in larsbx/agent-icm @ sha256:e0ea75600e3d136a
Edit the canonical template or estate.toml, then re-render: make estate
Hand-edits here are drift and `make estate-check` fails on them.
-->

# Agent policy — tui-story

Semantic graph and agent surfaces: an Elixir umbrella-ish pair plus a Python
Graphiti service, documented as an mdBook.

**Language / toolchain:** Elixir (`semantic_graph`, `auto_agent`) and Python (`graphiti_service`)
**CI:** GitHub Actions (`.github/workflows/ci.yml`) — but see the caveat below

This file is for whoever is working here next, human or otherwise. It states
what is settled, so that it does not get re-litigated by someone reading only
the code.

## Read first

- `README.md`
- `docs/`
- `specs/`

## Gates

Before proposing a change as finished, run:

1. suite —

   ```sh
   cd semantic_graph && mix test
   ```

2. integration suite —

   ```sh
   cd semantic_graph && mix test --only integration
   ```

3. services up —

   ```sh
   make start && make health
   ```

4. markdown lint —

   ```sh
   markdownlint-cli2 "**/*.md"
   ```

5. book builds —

   ```sh
   mdbook build && mdbook-linkcheck
   ```

Report honestly which ran. A partial environment that reports a skip is worth
more than one that passes vacuously.

## What this repository treats as evidence

- A change to the graph contract lands with a spec under `specs/` and the book
  section that describes it, in the same PR.
- Integration coverage is tagged, so `mix test` alone is not the whole claim —
  say which you ran.
- STANDING CAVEAT: `.github/workflows/ci.yml` runs `zig fmt --check src/
  tests/` and `zig build test` against a repository that contains no Zig. The
  green tick on that workflow currently proves nothing about this code. Fixing
  it is its own PR; until then, do not cite CI as evidence here.

## Standing prohibitions

- Never cite the current `ci.yml` as evidence that this repository's tests
  passed. Run them locally and say so.
- Never let a docs change land that the book cannot build.

## Scope discipline

- Make the change that was asked for. If the surrounding code is wrong in a way
  the task did not name, say so — do not widen the diff to fix it.
- If something is blocked, finish everything that is not, and say precisely what
  was left and why.
- Where a decision is already recorded, follow it or reopen it explicitly. Do
  not route around it in code.
