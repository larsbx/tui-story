<!--
Derived from templates/docs/AGENTS.md in larsbx/agent-icm @ sha256:e0ea75600e3d136a
Edit the canonical template or estate.toml, then re-render: make estate
Hand-edits here are drift and `make estate-check` fails on them.
-->

# Agent policy — tui-story

Semantic graph and agent surfaces: two Elixir projects (`semantic_graph`,
`auto_agent`) plus a Python Graphiti service, documented as an mdBook.

**Language / toolchain:** Elixir 1.17 on OTP 27, and Python 3.11 (`graphiti_service`)
**CI:** GitHub Actions (`.github/workflows/ci.yml`): one job per project -- semantic_graph, auto_agent, graphiti_service

This file is for whoever is working here next, human or otherwise. It states
what is settled, so that it does not get re-litigated by someone reading only
the code.

## Read first

- `README.md`
- `docs/`
- `specs/`

## Gates

Before proposing a change as finished, run:

1. semantic_graph suite —

   ```sh
   cd semantic_graph && mix test
   ```

2. auto_agent compiles —

   ```sh
   cd auto_agent && mix compile
   ```

3. the service's pins resolve and every module imports —

   ```sh
   cd graphiti_service && pip install -r requirements.txt && python -c 'import config, models, graphiti_client, main'
   ```

4. services up, for the integration paths —

   ```sh
   make start && make health
   ```

Report honestly which ran. A partial environment that reports a skip is worth
more than one that passes vacuously.

## What this repository treats as evidence

- The toolchain is pinned and it matters: `mix.lock` carries cowlib 2.20,
  whose `maybe` expression needs OTP 27, and `ratatouille -> ex_termbox`
  builds its C library with a vendored waf that needs Python 3.10 or older. CI
  pins both; a local run that skips either will fail for reasons that have
  nothing to do with the change.
- The suite runs headless. `config/test.exs` keeps the TUI from starting,
  because `Ratatouille.Window` cannot open a tty in CI, and points Tesla at
  `Tesla.Mock` so the Graphiti tests stop making real HTTP calls.
- STANDING GAP -- 17 of 65 tests in `semantic_graph` fail. They are
  pre-existing defects, uncovered when the project compiled for the first
  time: mostly tests that stop a supervised GenServer and start their own,
  plus four Ash errors. CI is red, and red is the honest reading until they
  are fixed.
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
- Never let Dependabot bump a pin here unreviewed. `graphiti-core` went 0.3.0
  -> 0.28.2 while `neo4j==5.14.0` stayed put, leaving `requirements.txt`
  unresolvable by pip -- and CI was too broken to notice.

## Scope discipline

- Make the change that was asked for. If the surrounding code is wrong in a way
  the task did not name, say so — do not widen the diff to fix it.
- If something is blocked, finish everything that is not, and say precisely what
  was left and why.
- Where a decision is already recorded, follow it or reopen it explicitly. Do
  not route around it in code.
