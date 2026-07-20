# isnow

> **A date/time pattern language for repetition.** One compact expression describes anything from a fixed instant to a complex recurrence, and answers a single question: _is it now?_

An **isnow** (the language, and a pattern string in it) is a **matcher**, not a generator. `*/*/1 * 12:*:00` matches every instant on the first of a month during the noon hour; an implementation exposes `is(isnow, instant)` — the isnow **holds** at an instant when every field constraint is satisfied. It is a strict superset of cron in expressiveness — sets, spans, exclusions, from-end counting, steps, and since/until bounds, over one uniform per-field algebra. Every concept has a fixed name: see [SPECIFICATION.md §0](SPECIFICATION.md#0-terminology).

```text
6                       every day at 06:00
M,W,F midnight          Mon/Wed/Fri at 00:00
11/ Th-[1] noon         last Thursday of November at noon
::+[9] >=6 <=18         every 9 seconds from 06:00 to 18:00
M-F-[1] noon            the last business day of the month at noon
+[90mn]                 every 90 minutes (a true interval, crossing hours)
M-F +[30mn] >=9 <=17    every 30 minutes, 9-to-5, on weekdays
```

This repository is the **grammar-first** home of the language: the ANTLR4 grammar is the source of truth, and every implementation is generated from it and verified against one shared corpus.

- **Grammar:** [IsnowParser.g4](IsnowParser.g4) · [IsnowLexer.g4](IsnowLexer.g4)
- **Specification (terminology + semantics):** [SPECIFICATION.md](SPECIFICATION.md)
- **Conformance corpus:** [conformance/](conformance/) — 180 language-agnostic cases every implementation must pass. Validate with `make corpus` (no toolchain needed).
- **Implementations:** [`tsvsheet/go-isnow`](https://github.com/tsvsheet/go-isnow) (the Go library), [`tsvsheet/isnow.go`](https://github.com/tsvsheet/isnow.go) (the `isnow` CLI and HTTP server, built on it), and [`tsvsheet/isnow.js`](https://github.com/tsvsheet/isnow.js) (the JS library + web playground).
- **Generate a parser:** `make image && make go` writes the Go parser into `../isnow.go/internal/isnowgrammar`, `make js` into `../isnow.js/src/isnowgrammar`; `python`/`java`/`cpp` land in `gen/<lang>/` for future implementations. `make help` lists targets. The Java/ANTLR toolchain is isolated in Docker; nothing else is needed to regenerate.

**Status:** Draft 0.1.0 — recovered and consolidated from the original 2011 design.
