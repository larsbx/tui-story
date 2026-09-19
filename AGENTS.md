<!--
Derived from templates/docs/AGENTS.md in larsbx/agent-icm @ sha256:e0ea75600e3d136a
Edit the canonical template or estate.toml, then re-render: make estate
Hand-edits here are drift and `make estate-check` fails on them.
-->

# Agent policy — tui-story

Semantic graph and agent surfaces: an Ash/Ratatouille TUI over PostgreSQL
(`semantic_graph`) and a self-modifying agent demo (`auto_agent`), documented
as an mdBook.

**Language / toolchain:** Elixir 1.17 on OTP 27, with PostgreSQL
**CI:** GitHub Actions (`.github/workflows/ci.yml`): one job per project --
  semantic_graph (with a PostgreSQL service) and auto_agent

This file is for whoever is working here next, human or otherwise. It states
what is settled, so that it does not get re-litigated by someone reading only
the code.

## Read first

- `README.md`
- `docs/architecture/`
- `specs/`

## Gates

Before proposing a change as finished, run:

1. semantic_graph suite; the alias creates and migrates the test database
   first —

   ```sh
   cd semantic_graph && mix test
   ```

2. auto_agent compiles —

   ```sh
   cd auto_agent && mix compile
   ```

3. PostgreSQL is up for local work —

   ```sh
   make start && make health
   ```

Report honestly which ran. A partial environment that reports a skip is worth
more than one that passes vacuously.

## What this repository treats as evidence

- The toolchain is pinned and it matters: `mix.lock` carries cowlib 2.20,
  whose `maybe` expression needs OTP 27, and `ratatouille -> ex_termbox`
  builds its C library with a vendored waf that needs Python 3.10 or older. CI
  pins both; a local run that skips either fails for reasons unrelated to the
  change.
- The graph is in PostgreSQL, and its two structural rules are in the schema:
  a unique index on `(from_vertex_id, to_vertex_id, relation_type)` and a
  `no_self_loops` check constraint. Both are tested by inserting through raw
  SQL rather than through the Ash action, because the claim is about what the
  graph can contain, not about what one action checks.
- The suite runs headless and hermetically: `config/test.exs` keeps the TUI
  from starting (`Ratatouille.Window` needs a tty), points Tesla at
  `Tesla.Mock`, and runs each test in a sandboxed transaction that is rolled
  back.
- STANDING GAP -- markdown is not linted and Elixir is not format-checked. The
  repository's own docs carry roughly 1,900 markdownlint violations across 41
  files and no `.ex` file has ever been formatted, so either gate could only
  ever be red. Fix the content first, then gate it.
- STANDING GAP -- the mdBook is not built. `book.toml` sets `src =
  "docs/book"` with `create-missing = false`, and `docs/book/` does not exist.

## Standing prohibitions

- Never add a check that cannot pass, or keep one that cannot fail. Both were
  here: a Zig job against a repository with no Zig, and a docs job that died
  in `Set up job` on a retired `upload-artifact@v3` before it linted anything.
- Never claim a green run covers the TUI. The TUI is the one part the suite
  cannot exercise, because it needs a terminal and CI has none.
- Never signal success by returning an error. `add_relationship` used to
  report an in-place certainty update as `{:error, _}`, so the caller logged
  every upgrade as a failure and dropped it; see ADR-007.
- Never reintroduce a second datastore or a second language without an ADR.
  ADR-006 proposed one, what got built never used the library it named, and it
  contributed no relationship to any graph before ADR-007 retired it.

## Scope discipline

- Make the change that was asked for. If the surrounding code is wrong in a way
  the task did not name, say so — do not widen the diff to fix it.
- If something is blocked, finish everything that is not, and say precisely what
  was left and why.
- Where a decision is already recorded, follow it or reopen it explicitly. Do
  not route around it in code.
