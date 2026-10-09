# Migration notice

This repository drifted from its purpose — typed semantic relations between
concepts — into a TUI, Phoenix API, Graphiti/Neo4j service, and agent runtime.
Its useful core now lives in
[`larsbx/semantic-categorical-oracle`](https://github.com/larsbx/semantic-categorical-oracle)
as the advisory concept pre-filter `Oracle.Concept.*`
(see `docs/concept-prefilter.md` there), pinned at revision
`2161f5de022d9db59551dac2f1f32f758b5e6ff3`.

| tui-story source | Oracle home |
|---|---|
| `resources/edge.ex` relation types, symbols | `Oracle.Concept.Relation` |
| `resources/edge.ex` duplicate/max-certainty rule, self-loop ban | `Oracle.Concept.Assertion.normalizeAssertions` |
| `llm/client.ex` relationship JSON (`String.to_atom`) | `Oracle.Concept.Assertion.fromRaw` (fail-closed) |
| `analysis/service.ex` case-insensitive concept matching | `Oracle.Concept.Validate` normal form |
| `specs/ValidationLayer.tla` S1–S4 | `Oracle.Concept.Validate.validateConcept` |
| `specs/SEMANTIC_ANALYSIS.md` §2 symmetry/transitivity, C2, C3 | `Oracle.Concept.Relation`, `Oracle.Concept.Filter` |

Not migrated: the TUI and layout, Phoenix/JSON:API, ETS storage,
`graphiti_service`, `auto_agent`, retry plumbing, and the manifestos.

New work on concept relations belongs in the oracle. This repository is a
candidate for archiving.
