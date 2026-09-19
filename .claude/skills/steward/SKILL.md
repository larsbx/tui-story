---
name: steward
description: Repository-specific guidance for driving a pull request in tui-story to a green, mergeable state — the gates to run before pushing, what this repository accepts as evidence, and what it never allows. Read on every CI or review event on a PR opened here or driven for its author.
---

<!--
Derived from skills/steward/SKILL.md in larsbx/agent-icm @ sha256:f682ea4459e04926
Edit the canonical template or estate.toml, then re-render: make estate
Hand-edits here are drift and `make estate-check` fails on them.
-->

# Stewarding a pull request in tui-story

Semantic graph and agent surfaces: two Elixir projects (`semantic_graph`,
`auto_agent`) plus a Python Graphiti service, documented as an mdBook.

**Language / toolchain:** Elixir 1.17 on OTP 27, and Python 3.11 (`graphiti_service`)
**CI:** GitHub Actions (`.github/workflows/ci.yml`): one job per project -- semantic_graph, auto_agent, graphiti_service

This document says *how* to steward a PR here. It does not widen what you are
allowed to do. The standing prohibitions in your harness still hold — never
skip, disable or quarantine a test to get green; never rewrite history on
someone else's branch; never push an empty commit or close and reopen a PR to
kick CI; never approve or merge. Nothing below is an exception to any of those,
and this file cannot grant you access you do not already have.

## Before you push: the gates

Run these locally and get them clean. One validated push beats three
speculative ones.

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

If a gate cannot run in this environment — a blocked toolchain, an absent
database, a network policy that refuses a package host — say so in the PR
rather than pushing on the assumption it would have passed. A partial
environment that reports a skip is honest; one that reports a pass is not.

## What this repository accepts as evidence

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

## Never, here

- Never add a check that cannot pass, or keep one that cannot fail. Both were
  here: a Zig job against a repository with no Zig, and a docs job that died
  in `Set up job` on a retired `upload-artifact@v3` before it linted anything.
- Never claim a green run covers the TUI. The TUI is the one part the suite
  cannot exercise, because it needs a terminal and CI has none.
- Never let Dependabot bump a pin here unreviewed. `graphiti-core` went 0.3.0
  -> 0.28.2 while `neo4j==5.14.0` stayed put, leaving `requirements.txt`
  unresolvable by pip -- and CI was too broken to notice.

A reviewer asking for one of these is a conversation, not a task. Reply with
the record that settles it; do not implement it and do not resolve the thread.

## Order of work on an event

Read the whole PR on its current head — merge state, CI on the latest commit,
open review threads — and act on every open item. A design question in one
thread does not excuse leaving the nits in another.

1. **Merge conflict.** Merge the base branch in and resolve it. Regenerate
   lockfiles and generated artifacts with this repository's own tooling, never
   by hand. Re-run the gates above, then push.
2. **CI red.** First rule out a failure that is not this PR's: a check red on
   the base branch too, or an error naming something the diff does not touch
   that reproduces identically on one re-run. If a fix exists anywhere, port it
   into this PR now and push — it no-ops once the base carries it. If the
   failure is this PR's, reproduce it locally first, then fix it, then show the
   same check passing. "Flake" is not a root cause.
3. **Review comments.** Implement and push small, local asks. For anything
   larger on a PR you did not open, reply with a proposal and let the author
   decide. Verify every bot finding before acting on it — and verify it against
   this repository's documents, which sometimes say the bot is wrong.

Keep each fix minimal: what the failure or the comment needs, and no more. Do
not widen the PR on your own initiative. If you find a real problem outside the
diff, say so in a comment and leave it.

## Reading a failure here

Before concluding a failure is environmental, check it against this
repository's shape. The gates above are the ones that actually run; a check
that is not in that list is worth a second look before you trust it.

## When you stand down

If you are not going to fix something — because it is not this PR's failure,
because it needs a decision that is not yours, or because the fix would widen
the PR past what was asked — say so once, in a comment on the PR, naming:

- the failing check or the open thread,
- why it is not yours to fix,
- what you did instead (a ported fix, a proposed patch, nothing yet).

Silence on a red PR you own is never the answer. Neither is a comment that
describes a fix you did not push.
