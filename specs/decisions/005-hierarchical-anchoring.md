# ADR 005 — Intervals anchor hierarchically to the civil calendar

**Status:** accepted (2026-07-14). Supersedes the epoch-anchoring half of [004](004-stepping-scope.md).

## Context

isnow v0.2 shipped intervals (`+[N<unit>]`, units `s`/`mn`/`h`/`d`) anchored at the **civil epoch** (1970-01-01T00:00:00 in the evaluation zone): an instant held when `totalUnitsFromEpoch mod N == 0`. That definition has a defect the "every Nt" framing hides — the phase **drifts** relative to civil boundaries whenever the stride does not divide the day (or week). `+[25h]` from the epoch lands at a different wall-clock time every day; `+[10d]` walks across month boundaries with no relationship to any calendar unit. Users reaching for "every 25 hours" or "every 10 days" almost always mean *within a civil cycle*, re-aligned to it — not a free-running lattice pinned to 1970.

The guiding instruction: **an anchor must be expressed relative to its parent civil unit and move with it** — days anchor within weeks, hours within days, minutes within hours — so the anchor slides forward with the calendar instead of being pinned to an absolute origin.

## Decision

An interval anchors to the **smallest civil container that holds its full stride**, and repeats *within* each container, re-aligning at the container boundary.

1. **Container ladder** (by size): `minute → hour → day → week → month → year`. Interval *periods* are only `s`/`mn`/`h`/`d`; week and month appear **only as containers**, never as interval units. (Repetition *by weeks* stays the existing year-anchored field-step `/+[Nw]`, which is a different construct — [semantics.md §Step](../contracts/semantics.md).)
2. **Container selection.** For an interval of grain `U` and period `N`, the container is the smallest cycle *strictly larger than `U`* whose nominal length (the longest that kind of cycle runs) is at least the stride `N·U`. A stride longer than a year has no larger civil cycle, so it re-aligns annually.
3. **Membership.** `holds(t) ≡ onBoundary(t) ∧ (posᵤ(t) mod N == 0)` where `onBoundary` is "every field finer than `U` is zero" and `posᵤ(t)` is the count of whole `U` grains from the start of the container to `t`. `pos` is measured **within** the container, so it wraps to 0 at each boundary automatically — the re-alignment is a consequence of the definition, not special-cased. Membership stays **O(1)**; no epoch arithmetic remains.
4. **Week start = Sunday** (weekday 1), matching isnow's own weekday numbering (`Su`=1 … `Sa`=7). `+[3d]` therefore holds on Sunday, Wednesday, and Saturday. This is a deliberate, documented choice (see *Misreads*).

### Worked containers

| interval | stride | container | holds at | re-aligns |
| --- | --- | --- | --- | --- |
| `+[30s]` | 30s | minute | :00, :30 | each minute |
| `+[90mn]` | 90m | day | 00:00, 01:30, 03:00 … | each midnight |
| `+[2h]` | 2h | day | 00, 02, … 22 | each midnight |
| `+[25h]` | 25h | week | Sun 00:00, Mon 01:00, … Sat 06:00 | each Sunday |
| `+[3d]` | 3d | week | Sun, Wed, Sat | each Sunday |
| `+[10d]` | 10d | month | 1st, 11th, 21st, (31st) | each 1st |
| `+[40d]` | 40d | year | day-of-year 1, 41, 81 … | each Jan 1 |

Ragged boundaries (day-of-month, day/hour-of-week, day-of-year when `N` does not divide the cycle) produce a **short gap** at the container edge. That civil re-alignment *is* the point of this ADR, not a defect.

## Consequences

- **Breaking change** from v0.2: every interval whose stride does not divide its container now matches different instants. Bumped to v0.3. Conformance and unit tests are recomputed against the civil model (the tests encode the new contract).
- **DST-sane.** Containers are civil, so `+[2h]` is 00:00, 02:00 … *local* every day rather than drifting by the zone's UTC offset.
- **The epoch is gone.** `daysFromCivil`/`totalUnits` arithmetic is deleted; `pos` needs only the broken-down wall-clock fields already in `instantCtx`.

## Deferred: the explicit pin

A concrete pin (`@<datetime>`) would let a user set the **phase offset** within the container (`+[90mn] @9:00` → phased to 09:00) and, at coarser granularity, **select** the container explicitly (overriding the size rule). Because `pos` already measures within a recurring container, a pin is a pure phase offset `A` — `(posᵤ(t) − A) mod N == 0` — and stays O(1). It is **additive** and needs grammar work (a new clause + parser regen across implementations), so it is scoped as the next increment; this ADR delivers the no-pin core (phase `A = 0`), which realizes the model's defaults. A *true absolute* origin pin (never re-aligning) remains the separate, heavier tool required only for COUNT.

## Misreads this invites (design must document)

- **"`+[3d]` is Mon/Thu/Sun."** No — week starts **Sunday** here, so it is Sun/Wed/Sat. ISO-minded users expect Monday.
- **"`+[25h]` is a clean 25-hour clock."** It re-aligns every Sunday, so one gap per week is shorter than 25h. Users wanting a free-running lattice want the (deferred) absolute origin pin instead.
- **"`+[10d]` is every 10 days forever."** It restarts on the 1st of each month; the last stride of a month is short.
