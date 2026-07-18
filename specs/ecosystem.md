# isnow ecosystem

## Goal

Grow isnow from a grammar-only repo into a full-featured, world-class language ecosystem: a named vocabulary for every concept, a Go implementation powering an `isnow` CLI (cron-superset tooling + an HTTP time server), a JS implementation for the web, a shared conformance corpus keeping every implementation honest, and docs. The defining operation everywhere is the membership test — `is(pattern, instant)` ([SPECIFICATION.md](../SPECIFICATION.md)).

## Bounded contexts

| Context | Home | Capability spec |
| --- | --- | --- |
| language-core (terminology, conformance corpus, generation retargeting) | `tsvsheet/isnow` (this repo) | [capabilities/language-core.md](capabilities/language-core.md) |
| go-engine (parse → AST → canonicalize → match → derive) | `tsvsheet/isnow.go` root package | [capabilities/go-engine.md](capabilities/go-engine.md) |
| go-cli (the `isnow` binary) | `tsvsheet/isnow.go` `cmd/isnow` + `internal/` | [capabilities/go-cli.md](capabilities/go-cli.md) |
| go-server (`isnow serve` HTTP API) | `tsvsheet/isnow.go` | [capabilities/go-server.md](capabilities/go-server.md) |
| js-engine (`@tsvsheet/isnow`) | `tsvsheet/isnow.js` | [capabilities/js-engine.md](capabilities/js-engine.md) |
| web-playground | `tsvsheet/www.tsvsheet.com` `/functions/isnow/playground/` | [capabilities/web-playground.md](capabilities/web-playground.md) |
| docs-governance (docs repos, manifest entries) | `tsvsheet/docs.isnow.go`, `tsvsheet/docs.isnow.js`, `tsvsheet/_admin` | [capabilities/docs-governance.md](capabilities/docs-governance.md) |

Build order and interfaces: [dependency-graph.yaml](dependency-graph.yaml). Cross-context contracts: [contracts/](contracts/). Architectural decisions: [decisions/](decisions/).

## Requirements (umbrella)

- R1. Every language concept has exactly one name, defined in SPECIFICATION.md and used consistently across grammar comments, code identifiers, CLI help, API responses, and docs ([contracts/terminology.md](contracts/terminology.md)).
- R2. A language-agnostic conformance corpus lives in this repo; every implementation executes it and passes 100% of applicable cases ([contracts/conformance-corpus.md](contracts/conformance-corpus.md)).
- R3. `tsvsheet/isnow.go` implements the full semantics (§6 of the spec) and ships the `isnow` CLI per template.cli standards: urfave/cli/v3, go-error sentinels, shared tools.repository Makefile gate green (fmt, lint, staticcheck, gocognit ≤ 7, govulncheck, 100% coverage of owned packages).
- R4. The CLI covers: the membership test (default command), occurrence derivation (`next`/`prev`), `canon`, `explain`, `wait`, cron-like `run` (with nowtab files), `build`, and `serve`.
- R5. `isnow serve` exposes the HTTP API of [contracts/http-api.md](contracts/http-api.md), including the status-code membership test, the builder, long-poll `wait`, and SSE `watch`.
- R6. `tsvsheet/isnow.js` implements the same semantics with the same conformance corpus, packaged as `@tsvsheet/isnow` per up.js conventions (node --test, 100% line coverage of the residue, eslint complexity ≤ 7).
- R7. Parsers remain generated from this repo's grammar (Docker-isolated ANTLR); generated trees are committed in implementation repos and excluded from their gates; `make gen` still produces python/java/cpp parsers for future implementations.
- R8. Each implementation repo gets its `docs.<repo>` sibling seeded from template.repo-docs; READMEs are badges + docs link only; `_admin/manifest.yaml` gains the required overrides.

## Acceptance criteria

- AC1. `grep`-audit: the terminology's terms appear in SPECIFICATION.md and are the only names used for those concepts in both implementations' public identifiers and docs.
- AC2. `make check` (and `make ci`) exit 0 in isnow.go; `make ci` exits 0 in isnow.js; both include the conformance suite.
- AC3. `isnow 'M,W,F noon' --at 2026-07-15T12:00:00` exits 0 and `--at 2026-07-15T12:00:01` exits 1 (Wednesday noon; second defaults to `:00`).
- AC4. `curl -s -o /dev/null -w '%{http_code}' localhost:8601/v1/is/6?at=2026-01-01T06:00:00Z` prints 204; at `07:00:00Z` prints 412.
- AC5. Every corpus case passes identically in Go and JS.
- AC6. All new repos exist under tsvsheet (private), push to `main`, and their CI workflows are green.

## Status

Draft accepted for implementation 2026-07-14. Complexity score ≈ 76 → decomposed process.
