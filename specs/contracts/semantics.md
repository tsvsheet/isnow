# Semantics contract

Cross-implementation pins for everything SPECIFICATION.md delegates to implementations (§6). Every rule here is exercised by the conformance corpus; Go and JS implement these identically.

## Field domains and cycles

| Field | Domain | Parent cycle |
| --- | --- | --- |
| year | 0–9999 | none (the window, when bounded) |
| month | 1–12 | year |
| day | 1–31 (calendar-clamped) | month |
| weekday | 1–7, Sunday = 1 | week |
| hour | 0–23 | day |
| minute | 0–59 | hour |
| second | 0–59 | minute |

Values beyond a parent cycle's actual length never match (day `31` simply doesn't hold in April — not an error); values outside the domain are `range` errors.

## The ladder (group → slot mapping)

- Date group: two slashes → Y/m/d; one slash → m/d. Time group: two colons → H:M:S; one colon → H:M.
- Bare group: a weekday symbol → weekday; a time symbol → the whole H:M:S; `*` → weekday (wildcard). A number → the hour slot when no time group constrains the hour *explicitly* (a present-but-empty `:`-slot does not constrain — the bare number fills it: `2 :30` is 02:30, `/1 18` is 18:00). When the hour is explicitly constrained, the number maps to weekday **only in the full three-group form** (`*/*/* 2 12:00` is Monday at noon); otherwise it is a `context` error (`2 12:00`). Numeric weekdays are valid only via this three-group routing.
- A slot *present but empty* (`11/`, `::+[9]`) is a wildcard.
- Absent-field defaults: if **no time field is provided at all**, time defaults to `*:*:00` (so `M` and `12/25` match every minute of their days, and the bare `*` ⇒ `*/*/* * *:*:00`). When any time field is provided (a time group or a bare hour), absent *finer* time fields default to `00` and absent/empty *coarser* ones to wildcard (`6` ⇒ `06:00:00`; `:0,30` ⇒ `*:00,30:00`). Absent date fields and weekday are always wildcards.
- At most one of each group kind; a second date/time group, a second bare group competing for the same slot (`6 7`, `M Tu` — write `M,Tu`), a time symbol alongside a time group, or a bare group that can't claim a free slot is a `context` error. A present-but-empty slot is free — its wildcard is a default, not a claim. Day and weekday constraints are **both** required to hold (AND — isnow has no cron day-OR quirk).

## Algebra semantics

- **Span** `v-v`: inclusive; may wrap on cyclic fields (`22-2` hours = 22,23,0,1,2; `F-M` = F,Sa,Su,M); a descending year span is a `range` error. `v-*` runs to the parent cycle's end; `*-v` is a `context` error.
- **From-end value** `-v`: the **tail** of length v of the parent cycle — day `-1` = {last day}, day `-15` = the last 15 days, weekday `-2` = {F, Sa}. A unit compound tail (`-2w1d`) is a tail of that total length in days. The tail length must be **1 ≤ v ≤ the cycle size** (day ≤ 31, weekday ≤ 7, hour ≤ 24, minute/second ≤ 60, month ≤ 12); a length of 0 or one exceeding the cycle is a `range` error (`/-0`, `/-40`, weekday `-2w` all reject). Year `-v` is a `context` error unless the pattern is bounded, where the window is the year's parent (year `-1` = the window's last year).
- **Step** `v±[N]`: two readings selected by the anchor:
  - Numeric, wildcard, or elided anchor → arithmetic progression. `+[N]`: value ∈ {anchor + kN, k ≥ 0} within the parent cycle, elided anchor = the cycle's first value (`:0+[15]` = :00,:15,:30,:45). `-[N]`: the descending mirror — value ∈ {anchor − kN, k ≥ 0}, elided anchor = the cycle's **last** value (`:-[15]` = :59,:44,:29,:14). Multiple quantities are a union of progressions. The stride N must be **1 ≤ N < the cycle size**: a stride ≥ the cycle cannot progress (it collapses to the anchor) and is a `range` error (`:0+[90]`, `0+[25]`, `::+[60]` all reject) — a true "every N units" period that crosses the cycle is a *unit step* (below), not a field-local step. **Year**: `+[N]` is an open progression (`2000+[4]` = every 4th year from 2000, no cycle guard); year `-[N]` or an elided-anchor year step is a `context` error unless bounded.
  - Weekday-symbol anchor → occurrence selection within the **month**: `Monday+[3]` = the 3rd Monday, `Thursday-[1]` = the last Thursday, `M+[1,3]` = the 1st and 3rd Monday. The occurrence index must be **1 ≤ k ≤ 5** (a month holds at most five of any weekday); `Monday+[0]` and `Monday+[6]` are `range` errors.
  - **Week-unit step** `+[Nw]` (day field): the day's week index — `(day_of_year − 1) / 7`, zero-based — is ≡ anchor (default 0) mod N. The stride must be **1 ≤ N ≤ 53** and the anchor **< N** (`/5+[3w]`, `/+[99w]` reject). `-[Nw]` is reserved: a `context` error.
  - An out-of-representation magnitude (a number that overflows) is a `range` error.
- **Exclusion** `!`: complements the field's full expansion after sets, spans, tails, and steps.
- **Set**: union of its terms; the algebra distributes over members.
- An unknown unit name (`5x`, `+[3q]`) is a `symbol` error.

## Symbols

Canonical weekday names Sunday…Saturday; resolution is case-insensitive unique-prefix, with the spec's single letters (`Su M Tu W Th F Sa`) and runs `MWF`, `SS` (weekend), `TT` (Tue+Thu) always valid. **`m` is always Monday.** Time symbols are `noon`/`midday` = 12:00:00 and `midnight` = 00:00:00, resolved by case-insensitive unique prefix of the three words plus the abbreviations `mn` (midnight) and `md` (midday); `mi` and `mid` are ambiguous → `symbol` errors, as are `T` and `S`. Time symbols are valid only as a bare group.

## Bounds

- A bound's sub-spec canonicalizes like any isnow **except** for bare-number routing: in a bound, a bare number of four digits → year, otherwise → hour (domain 0–23, else `range` — `>=2011` is a year, `>=6` a time, `>=25` a `range` error). It must constrain only with wildcards and **exact values** (sets, spans, tails, steps, exclusions, or a weekday field inside a bound are `context` errors), and compares **positionally**: only its non-wildcard fields, as a tuple in field order. `>=2011` ⇒ Y ≥ 2011; `<9/1` ⇒ (m, d) < (9, 1) in every year; `>=6` ⇒ (H, M, S) ≥ (6, 0, 0) daily. `>`/`<` are exclusive, `>=`/`<=` inclusive.
- The **window** is the set of instants satisfying every bound. Positional comparison on non-year fields makes windows *recurring*: `>=6 <=18` is a daily window.
- **Stepping context** (SPECIFICATION.md §5): steps are **field-local** — a step resets within its parent cycle — in every context. SPECIFICATION.md §5's *continuous* stepping across a bounded window is a deferred future extension ([decision 004](../decisions/004-stepping-scope.md)); until it ships, the corpus carries no case that distinguishes it from field-local stepping (every bounded-step case falls where the two coincide). Bounds themselves are fully honored: they filter which instants can hold and cap derivation.

## Canonical rendering

- The canonical form is `Y/m/d w H:M:S` with the pattern's bounds appended, space-separated.
- Exact values, span endpoints, and from-end values are zero-padded to the field's width (two digits; four for year): `12/-1` renders `-01`, `8-12` renders `08-12`. `*` renders `*`.
- Step expressions and unit compounds render verbatim as written (anchor and quantities unpadded): `:0+[5]` ⇒ `*:*:0+[5]`, `12/-2w1d` ⇒ `*/12/-2w1d`. Sets preserve written member order; `!` renders before its terms.
- A weekday renders as its full canonical name whether written symbolically or numerically, as an exact value or a span endpoint (`M` ⇒ `Monday`, three-group `2` ⇒ `Monday`, `2-6` ⇒ `Monday-Friday`); runs expand to full-name sets in ascending weekday order (`MWF` ⇒ `Monday,Wednesday,Friday`, `SS` ⇒ `Sunday,Saturday`, `TT` ⇒ `Tuesday,Thursday`). A **numeric weekday step anchor stays numeric** (`2+[1]` ⇒ `2+[1]`) — it is an arithmetic progression, distinct from a symbolic anchor's occurrence selection, and must not reparse as one. A time symbol renders as its numeric fields.
- A bound renders as its operator plus the **full** `Y/m/d w H:M:S` canonical form of its sub-spec (with its bound-specific bare-number routing), so it round-trips unambiguously: `<9/1` ⇒ `<*/09/01 * *:*:*`, `>=2011` ⇒ `>=2011/*/* * *:*:*`. (Unconstrained fields render as `*`, including `*:*:*` for time — the one place `*` appears in a second slot, since a bound is not subject to the main form's `:00` second default.)

## Evaluation and time zones

- `holds` truncates the instant to whole seconds and evaluates the broken-down **wall-clock fields** in the evaluation zone (Go: `at.Location()`; JS: the parse-time `timeZone`). It is a pure function of those fields: during a DST fold, both absolute instants sharing matching wall fields hold; wall times skipped by a DST gap hold at no absolute instant.
- Derivation (`next`/`prev`) enumerates absolute instants whose wall fields match, strictly monotonic from `from`, bounded by the window and the 100-year horizon. A DST fold can therefore yield two absolute occurrences of one wall time; a gap yields none.
- Enumeration must be analytic in the time dimension — implementations must not scan second-by-second through non-matching regions (an observable requirement: deriving `next` of `12/25 midnight` from any instant completes in interactive time).
