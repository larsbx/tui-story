# ADR-008: Gleam for kernels, and the spike that proved the toolchain

## Status

Accepted.

## Context

The estate adopted a rule — `agent-icm`, `context/30-stack/10-gleam-kernels.md`
— that a kernel inside an Ash Elixir application is written in Gleam rather
than Elixir. A kernel there means: pure and total, load-bearing when wrong, and
spending its bulk rejecting states Elixir lets you express.

That rule shipped **gated**, deliberately. Nothing in the estate had compiled a
line of Gleam, so the policy required the first adopting repository to land a
spike before any kernel, and to record the versions it adopted. This is that
spike and that record.

The gate exists because of ADR-006 in this same repository: a library proposed,
a service built that never called it, and `TODO: implement when available` left
in place for a year while the library was on PyPI the whole time. A policy that
is never exercised decays the same way.

## Decision

Adopt Gleam in `semantic_graph` for kernels, and prove the toolchain now with a
module that nothing authoritative depends on.

**`src/semantic_graph_certainty.gleam`** classifies a certainty into a display
band. It is a kernel by every criterion — pure, total, no I/O — but it is
presentation only, so the spike carries no blast radius. It still demonstrates
the property the policy is about: `Band` has four variants and the compiler
will not let a `case` over it miss one.

**`SemanticGraph.CertaintyBand`** is the single Elixir module permitted to call
it. A compiled Gleam module looks like an Erlang module from Elixir
(`:semantic_graph_certainty.classify/1`), and a codebase calling that from
twenty places has a boundary in name only.

### Versions adopted

| | Version | Note |
| --- | --- | --- |
| Gleam | 1.18.1 | installed in CI by `erlef/setup-beam` |
| `mix_gleam` | 0.6.2 | a Mix **archive**, pinned explicitly in CI |
| `gleam_stdlib` | ~> 1.0 | resolved 1.0.5 |
| `gleeunit` | ~> 1.0 | resolved 1.11.0 |

## Consequences

### Positive

- The policy is exercised rather than asserted. Every mechanical claim it makes
  is now established here rather than quoted from a README.
- A kernel that matters can now be written without also discovering the
  toolchain.
- The boundary shape is settled and tested: Gleam variants carrying fields
  arrive as tuples tagged with the constructor, variants carrying none as bare
  atoms. `SemanticGraph.CertaintyBand` maps them one at a time with no
  catch-all, so a new variant on the Gleam side breaks loudly.

### Negative

- **`mix_gleam` 0.6.2 was published 2023-11-16** and is the newest release.
  Gleam has gone 1.0 and reached 1.18.1 since. It works — this spike is the
  evidence — but it is unmaintained across a major version boundary, and that
  is a standing risk, not a solved problem. If it breaks, the fallback is to
  run `gleam build` directly and point `erlc_paths` at its output, which is
  what the archive does anyway.
- An archive is a machine-local install, not a dependency. Nothing in the
  repository records which version built a given commit unless CI pins it, so
  CI pins it. For an estate that pins vendored packages by SHA-256 this is
  weaker than usual and worth knowing.
- Contributors need the Gleam compiler locally, not only Elixir and OTP.
- `mix gleam.test` starts the application, so it runs under `MIX_ENV=test`
  after ExUnit has created the database.

### Neutral

- No existing behaviour changed. Nothing was ported; a new module was added.
- Ash is untouched. It adds no compiler of its own, so `[:gleam |
  Mix.compilers()]` has nothing to collide with.

## Alternatives Considered

### Alternative 1: Wait for a maintained mix_gleam

Rejected. The policy's whole point is that it must be exercised to be real, and
"wait for the tooling" is the exact failure mode ADR-006 recorded. The staleness
is documented above instead, with the fallback named.

### Alternative 2: Build Gleam separately and vendor the compiled Erlang

Point `erlc_paths` at the output of a plain `gleam build`, with no archive.
Rejected for now: it is the documented fallback, but it hand-rolls what the
archive already does, and the archive works. Revisit if it stops working.

### Alternative 3: Port a real kernel immediately

Rejected: the policy says the spike lands before any kernel. Porting a kernel
means keeping the Elixir implementation as an independent oracle until the
Gleam one is proved against committed vectors — a larger change that should not
be entangled with discovering whether the compiler runs at all.

## Notes

Verified before this was written, on Elixir 1.17.3 / OTP 27 / Gleam 1.18.1:

- `mix compile` — Gleam compiles inside the Ash application, warning-free.
- Representation across the boundary — `Classified(Confident)` arrives as
  `{:classified, :confident}`, `OutOfRange(1.5)` as `{:out_of_range, 1.5}`.
- `mix test` — 50 tests, 0 failures (47 before the spike, plus 3 adapter tests).
- `mix gleam.test` — 2 passed, no failures.

One wrinkle worth recording: `mix_gleam` generates a `gleam.toml` containing
only the package name, and Gleam 1.18 then warns that every `gleam/*` import is
a transitive dependency and says that will become a compile error in a future
version. A `gleam.toml` committed at the project root, naming `gleam_stdlib`
directly, is respected and the warning goes away. The generated one is not
overwritten when a real one exists.

## Date

2026-09-19
