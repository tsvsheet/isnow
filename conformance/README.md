# isnow conformance corpus

The language-agnostic test corpus that keeps every implementation honest. [SPECIFICATION.md](../SPECIFICATION.md) defines the grammar and [SEMANTICS.md](../SEMANTICS.md) pins the shared semantics; this corpus is their machine-checked form — one YAML file per theme, and every implementation must pass 100% of the cases. Implementations consume the corpus directly from a checkout of this repository (typically a sibling checkout, e.g. `../isnow/conformance/`), loading every `*.yaml` file and running each case through their own parser/evaluator; a suite may self-skip when the checkout is absent, but never skip individual cases.

Validate the corpus itself — YAML well-formed, names unique, shapes recognized — with [validate.py](validate.py) (`python3 validate.py`, or `make corpus` from the repo root; no dependencies needed).

## File format

Each file is a YAML document: `cases:` — a list of case objects. Every case has a unique `name` (kebab-case, unique corpus-wide) and exactly one of the shapes below. All instants are RFC 3339 with offset; the evaluation zone is the fixed offset given, unless the case carries `tz:` (an IANA zone name — used for DST cases), which overrides it. Weekday numbering: Sunday = 1.

### holds case

```yaml
- name: wednesday-noon-holds
  isnow: "M,W,F noon"
  at: "2026-07-15T12:00:00-05:00"
  holds: true
```

### canonical case

```yaml
- name: bare-hour-canonicalizes
  isnow: "6"
  canonical: "*/*/* * 06:00:00"
```

### next / prev case (derivation)

```yaml
- name: next-last-thursday-november
  isnow: "11/ Th-[1] noon"
  from: "2026-01-01T00:00:00Z"
  next:
    - "2026-11-26T12:00:00Z"
```

`next` lists occurrences strictly after `from`, in order; its length is the `n` requested. A `prev` case is the mirror: occurrences strictly before `from`, nearest first. An empty list (`next: []`) asserts that one occurrence was requested and none exists within the window/horizon.

### error case (parse or semantic rejection)

```yaml
- name: ambiguous-symbol-rejected
  isnow: "T noon"
  error: symbol
```

`error` values are stable machine-readable codes shared by all implementations: `syntax` (the grammar rejects the token stream), `symbol` (unknown or ambiguous name/unit), `range` (value outside its field's domain), `context` (semantically invalid construct, e.g. an unbounded year from-end).

## Files

180 cases across eight themed files:

- [structure.yaml](structure.yaml) — groups, the shorthand ladder, and canonical forms
- [algebra.yaml](algebra.yaml) — wildcard, exact value, set, field exclusion, span, from-end, unit compound, step
- [symbols.yaml](symbols.yaml) — symbolic name resolution (weekdays, runs, time symbols)
- [bounds.yaml](bounds.yaml) — since/until bounds, windows, stepping under bounds
- [exclusions.yaml](exclusions.yaml) — pattern-level `! <spec>` exclusions
- [intervals.yaml](intervals.yaml) — `+[N<unit>]` intervals and hierarchical civil anchoring
- [derivation.yaml](derivation.yaml) — next/prev occurrence derivation
- [errors.yaml](errors.yaml) — rejected inputs, by stable error code

Every SPECIFICATION.md example appears as a case.
