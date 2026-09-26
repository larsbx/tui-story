<!--
Derived from templates/docs/CONTRIBUTING.md in larsbx/agent-icm @ sha256:88bf9172c22bc8da
Edit the canonical template or estate.toml, then re-render: make estate
Hand-edits here are drift and `make estate-check` fails on them.
-->

# Contributing to tui-story

Semantic graph and agent surfaces: an Ash/Ratatouille TUI over PostgreSQL
(`semantic_graph`) and a self-modifying agent demo (`auto_agent`), documented
as an mdBook.

**Language / toolchain:** Elixir 1.17 on OTP 27 with PostgreSQL, plus Gleam 1.18 for kernels
**CI:** Woodpecker on Forgejo is canonical CI; GitHub Actions
  (`.github/workflows/ci.yml`) is advisory review-mirror evidence only. Both
  exercise semantic_graph (with PostgreSQL) and auto_agent gates.

Read these first — they are normative, not background:

- `README.md`
- `docs/architecture/`
- `specs/`

---

## The gates

Run these before you open a pull request. Paste what they said into the PR's
evidence table.

1. semantic_graph suite; the alias creates and migrates the test database
   first —

   ```sh
   cd semantic_graph && mix test
   ```

2. the Gleam kernel suite —

   ```sh
   cd semantic_graph && MIX_ENV=test mix gleam.test
   ```

3. auto_agent compiles —

   ```sh
   cd auto_agent && mix compile
   ```

4. PostgreSQL is up for local work —

   ```sh
   make start && make health
   ```

A check you did not run is not evidence. Say which ones you skipped and why;
the pull request template has a place for exactly that.

## What counts as evidence here

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
- Kernels are Gleam, per the estate policy, and ADR-008 is the spike that
  proved the toolchain rather than assuming it: Gleam compiles inside the Ash
  application, both suites run, and the versions are pinned.
  `SemanticGraph.CertaintyBand` is the only module permitted to call across
  the boundary, and it maps each Gleam variant explicitly so a new one breaks
  loudly instead of falling through.
- STANDING RISK -- `mix_gleam` 0.6.2 was published in November 2023 and is the
  newest release, while Gleam has since gone 1.0 and reached 1.18.1. It works,
  and CI pins it, but an archive is a machine-local install rather than a
  dependency. If it breaks, run `gleam build` directly and point `erlc_paths`
  at its output.
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
- Never start a new load-bearing kernel -- pure, total, and where being wrong
  is a violation rather than an inconvenience -- without checking the Gleam
  policy in `agent-icm` (`context/30-stack/10-gleam-kernels.md`). It says when
  the language boundary is worth it, when it is not, and that the toolchain
  must be proved by a spike before the first kernel lands.

These are not style preferences. Each one is settled somewhere in the documents
above; changing one is a decision record, not a pull request comment.

## Working shape

1. **Branch** from the default branch.
2. **Make the failing case first** where this repository's discipline requires
   it, and in every case make sure the new test fails without your change.
3. **Run the gates.** All of them, or name the ones you did not.
4. **Update the surfaces.** Documentation, status tables, ledgers and generated
   artifacts that name the behaviour you changed are part of the change, not a
   follow-up. Regenerate generated files with their tooling; never hand-edit one.
5. **Open the pull request** using the template. Fill in *What this does not
   establish* — it is required, and it is the section reviewers read first.

## Claim discipline

State exactly what your change establishes and no more.

- A search that stopped at a limit reports where it stopped.
- A bounded failure is not an absence.
- A refusal is not a clean answer.
- A translation preserves or lowers authority; it never raises it.
- "Verified" unqualified is not a claim. Say verified *by what*.

## Commits

Imperative, present tense, describing the difference: `Add the M-adic ball
carrier`, `Reject a singular M before the zeroth power`. The body carries the
reasoning when the subject cannot.
