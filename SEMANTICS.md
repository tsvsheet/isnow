# isnow — Semantics

[SPECIFICATION.md](SPECIFICATION.md) defines the grammar and terminology; this document pins the semantics every implementation must share — everything the specification delegates to implementations ([§6](SPECIFICATION.md#6-grammar-vs-semantics-the-split-an-implementation-owns)). The [conformance corpus](conformance/) is the machine-checked form of these pins: every rule here is exercised by corpus cases, and every implementation passes 100% of them.

## Field domains and cycles

| Field   | Domain                  | Parent cycle                    |
| ------- | ----------------------- | ------------------------------- |
| year    | 0–9999                  | none (the window, when bounded) |
| month   | 1–12                    | year                            |
| day     | 1–31 (calendar-clamped) | month                           |
| weekday | 1–7, Sunday = 1         | week                            |
| hour    | 0–23                    | day                             |
| minute  | 0–59                    | hour                            |
| second  | 0–59                    | minute                          |

Values beyond a parent cycle's actual length never match (day `31` simply doesn't hold in April — not an error); values outside the domain are `range` errors.

## The ladder (group → slot mapping)

- Date group: two slashes → Y/m/d; one slash → m/d. Time group: two colons → H:M:S; one colon → H:M.
- Bare group: a weekday symbol → weekday; a time symbol → the whole H:M:S; `*` → weekday (wildcard). A number → the hour slot when no time group constrains the hour _explicitly_ (a present-but-empty `:`-slot does not constrain — the bare number fills it: `2 :30` is 02:30, `/1 18` is 18:00). When the hour is explicitly constrained, the number maps to weekday **only in the full three-group form** (`*/*/* 2 12:00` is Monday at noon); otherwise it is a `context` error (`2 12:00`). Numeric weekdays are valid only via this three-group routing.
- A slot _present but empty_ (`11/`, `::+[9]`) is a wildcard.
- Absent-field defaults: if **no time field is provided at all**, time defaults to `*:*:00` (so `M` and `12/25` match every minute of their days, and the bare `*` ⇒ `*/*/* * *:*:00`). When any time field is provided (a time group or a bare hour), absent _finer_ time fields default to `00` and absent/empty _coarser_ ones to wildcard (`6` ⇒ `06:00:00`; `:0,30` ⇒ `*:00,30:00`). Absent date fields and weekday are always wildcards.
- At most one of each group kind; a second date/time group, a second bare group competing for the same slot (`6 7`, `M Tu` — write `M,Tu`), a time symbol alongside a time group, or a bare group that can't claim a free slot is a `context` error. A present-but-empty slot is free — its wildcard is a default, not a claim. Day and weekday constraints are **both** required to hold (AND — isnow has no cron day-OR quirk).

## Algebra semantics

- **Span** `v-v`: inclusive; may wrap on cyclic fields (`22-2` hours = 22,23,0,1,2; `F-M` = F,Sa,Su,M); a descending year span is a `range` error. `v-*` runs to the parent cycle's end; `*-v` is a `context` error.
- **From-end value** `-v`: the **tail** of length v of the parent cycle — day `-1` = {last day}, day `-15` = the last 15 days, weekday `-2` = {F, Sa}. A unit compound tail (`-2w1d`) is a tail of that total length in days. The tail length must be **1 ≤ v ≤ the cycle size** (day ≤ 31, weekday ≤ 7, hour ≤ 24, minute/second ≤ 60, month ≤ 12); a length of 0 or one exceeding the cycle is a `range` error (`/-0`, `/-40`, weekday `-2w` all reject). Year `-v` is a `context` error unless the pattern is bounded, where the window is the year's parent (year `-1` = the window's last year).
- **Step** `v±[N]`: two readings selected by the anchor:
  - Numeric, wildcard, or elided anchor → arithmetic progression. `+[N]`: value ∈ {anchor + kN, k ≥ 0} within the parent cycle, elided anchor = the cycle's first value (`:0+[15]` = :00,:15,:30,:45). `-[N]`: the descending mirror — value ∈ {anchor − kN, k ≥ 0}, elided anchor = the cycle's **last** value (`:-[15]` = :59,:44,:29,:14). Multiple quantities are a union of progressions. The stride N must be **1 ≤ N < the cycle size**: a stride ≥ the cycle cannot progress (it collapses to the anchor) and is a `range` error (`:0+[90]`, `0+[25]`, `::+[60]` all reject) — a true "every N units" period that crosses the cycle is an _interval_ (below), not a field-local step. **Year**: `+[N]` is an open progression (`2000+[4]` = every 4th year from 2000, no cycle guard); year `-[N]` or an elided-anchor year step is a `context` error unless bounded.
  - Weekday-symbol anchor → occurrence selection within the **month**: `Monday+[3]` = the 3rd Monday, `Thursday-[1]` = the last Thursday, `M+[1,3]` = the 1st and 3rd Monday. The occurrence index must be **1 ≤ k ≤ 5** (a month holds at most five of any weekday); `Monday+[0]` and `Monday+[6]` are `range` errors.
  - Weekday-**span** anchor → **BYSETPOS**: the k-th day of the month whose weekday lies in the span. `M-F-[1]` = the last **business day** of the month, `M-F+[1]` = the first, `M-F+[1,3]` = the first and third. The index is 1-based among the month's matching days, counted from the start (`+`) or end (`-`); it must be `1 ≤ k ≤ 31`. (A weekday-span step routes here; a numeric-_value_ span step like `8-12+[2]` on a time field stays an arithmetic span-restricted step.)
  - **Week-unit step** `+[Nw]` (day field): the day's week index — `(day_of_year − 1) / 7`, zero-based — is ≡ anchor (default 0) mod N. The stride must be **1 ≤ N ≤ 53** and the anchor **< N** (`/5+[3w]`, `/+[99w]` reject). `-[Nw]` is reserved: a `context` error.
  - An out-of-representation magnitude (a number that overflows) is a `range` error.
- **Exclusion** `!`: complements the field's full expansion after sets, spans, tails, and steps.
- **Set**: union of its terms; the algebra distributes over members.
- An unknown unit name (`5x`, `+[3q]`) is a `symbol` error.

## Symbols

Canonical weekday names Sunday…Saturday; resolution is case-insensitive unique-prefix, with the spec's single letters (`Su M Tu W Th F Sa`) and runs `MWF`, `SS` (weekend), `TT` (Tue+Thu) always valid. **`m` is always Monday.** Time symbols are `noon`/`midday` = 12:00:00 and `midnight` = 00:00:00, resolved by case-insensitive unique prefix of the three words plus the abbreviations `mn` (midnight) and `md` (midday); `mi` and `mid` are ambiguous → `symbol` errors, as are `T` and `S`. Time symbols are valid only as a bare group.

## Exclusions

A **pattern-level exclusion** carves specific instants out of a pattern: the isnow does **not** hold when the exclusion's sub-spec holds. It is written `! <spec>` — a `!` set off from its sub-spec by a group separator — appearing after the main spec, interleaved with bounds: `M-F ! 12/25` is every weekday except December 25.

- **Disambiguation.** The separator around `!` distinguishes a pattern exclusion from a field-level exclusion. `! 12/25` (separated) is the pattern exclusion "not on Dec 25"; `!12/25` (no separator) is the field exclusion `!12` in a date group — "the 25th of every month except December". This mirrors the grammar (`exclusion : GSEP BANG GSEP spec`).
- **Whole-period.** An exclusion sub-spec's absent time fields default to **wildcard**, so `! 12/25` excludes all of December 25, not just midnight. Provide a time to narrow it (`! 12/25 noon`).
- **Semantics.** `Holds(t) = main(t) ∧ bounds(t) ∧ intervals(t) ∧ ¬(any exclusion sub-spec holds at t)`. Multiple exclusions form a holiday list: `noon ! 12/25 ! 1/1 ! 7/4`.
- **Rendering.** Exclusions render after the main form, intervals, and bounds: `M-F ! 12/25` ⇒ `*/*/* Monday-Friday *:*:00 ! */12/25 * *:*:*`.

## Intervals

An **interval** is a true periodic recurrence — "every N units" — written as a bare group `+[N<unit>]` with an interval unit: `s` (second), `mn` (minute), `h` (hour), `d` (day). It is distinct from a field-local step: a step resets within one field's cycle, whereas an interval crosses field boundaries — `+[90mn]` spans hours, `+[25h]` spans days, `+[10d]` spans months.

- **Anchor (hierarchical, civil).** An interval anchors to the **smallest civil container that holds its full stride**, and repeats _within_ each container, re-aligning at the container boundary — so the anchor "moves with its unit" instead of being pinned to an absolute origin. The container ladder is `minute → hour → day → week → month → year`; the container is the smallest cycle _strictly larger than the grain_ whose nominal length is at least `N·<unit>` (a stride longer than a year re-aligns annually). The **week container starts on Sunday** (weekday 1). Examples: `+[90mn]` → day (00:00, 01:30, 03:00, …); `+[2h]` → day (00,02,…,22); `+[3d]` → week (Sun, Wed, Sat); `+[25h]` → week (Sun 00:00, Mon 01:00, … Sat 06:00); `+[10d]` → month (1st, 11th, 21st, 31st); `+[40d]` → year (day-of-year 1, 41, 81, …).
- **Grid.** Let `pos` be the count of whole units from the **start of the container** to the instant. The interval holds iff `pos mod N == 0` **and** the finer-than-unit fields are 0 (`+[Nmn]` requires second 0; `+[Nh]` minute and second 0; `+[Nd]` the whole time 00:00:00). Because `pos` is measured within the container it wraps to 0 at each boundary, so re-alignment is automatic and membership stays O(1). When `N` does not divide the container evenly the final stride before the boundary is short (a deliberate civil re-alignment, e.g. `+[3d]`: Saturday then Sunday is a one-day gap). A second-grained interval frees the second field (its time default becomes `*:*:*`); coarser ones keep the `:00` second default.
- **Composition.** An interval is ANDed with the rest of the pattern: `M-F +[90mn] >=6 <=18` is every 90 minutes on weekdays within the 06:00–18:00 window. Multiple intervals may co-occur.
- **Domain.** `N ≥ 1`; a descending interval (`-[N<unit>]`) is a `context` error; `+[0mn]` and an overflowing magnitude are `range` errors. The units `w`/`mo`/`y` are **not** interval units — weeks are the week-step (`/+[Nw]`), months and years the field sets/steps — so `+[2w]` stays a (day-slot) week step, not an interval.
- **Rendering.** Intervals render after the `Y/m/d w H:M:S` form and before any bounds: `M-F +[90mn] >=6 <=18` ⇒ `*/*/* Monday-Friday *:*:00 +[90mn] >=*/*/* * 06:00:00 <=*/*/* * 18:00:00`.

## Bounds

- A bound's sub-spec canonicalizes like any isnow **except** for bare-number routing: in a bound, a bare number of four digits → year, otherwise → hour (domain 0–23, else `range` — `>=2011` is a year, `>=6` a time, `>=25` a `range` error). It must constrain only with wildcards and **exact values** (sets, spans, tails, steps, exclusions, or a weekday field inside a bound are `context` errors), and compares **positionally**: only its non-wildcard fields, as a tuple in field order. `>=2011` ⇒ Y ≥ 2011; `<9/1` ⇒ (m, d) < (9, 1) in every year; `>=6` ⇒ (H, M, S) ≥ (6, 0, 0) daily. `>`/`<` are exclusive, `>=`/`<=` inclusive.
- The **window** is the set of instants satisfying every bound. Positional comparison on non-year fields makes windows _recurring_: `>=6 <=18` is a daily window.
- **Stepping context**: steps are **field-local** — a step resets within its parent cycle — in every context. The _continuous_ stepping across a bounded window described in [SPECIFICATION.md §5](SPECIFICATION.md#5-bounds-and-increment-context) is a deferred future extension; until it ships, the conformance corpus carries no case that distinguishes it from field-local stepping (every bounded-step case falls where the two coincide). Bounds themselves are fully honored: they filter which instants can hold and cap derivation.

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
