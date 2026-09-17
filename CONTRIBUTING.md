<!--
Derived from templates/docs/CONTRIBUTING.md in larsbx/agent-icm @ sha256:88bf9172c22bc8da
Edit the canonical template or estate.toml, then re-render: make estate
Hand-edits here are drift and `make estate-check` fails on them.
-->

# Contributing to tui-story

Semantic graph and agent surfaces: an Elixir umbrella-ish pair plus a Python
Graphiti service, documented as an mdBook.

**Language / toolchain:** Elixir (`semantic_graph`, `auto_agent`) and Python (`graphiti_service`)
**CI:** GitHub Actions (`.github/workflows/ci.yml`) — but see the caveat below

Read these first — they are normative, not background:

- `README.md`
- `docs/`
- `specs/`

---

## The gates

Run these before you open a pull request. Paste what they said into the PR's
evidence table.

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

A check you did not run is not evidence. Say which ones you skipped and why;
the pull request template has a place for exactly that.

## What counts as evidence here

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
