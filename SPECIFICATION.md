# isnow — Specification (DTimpalr)

**Date/Time Pattern Language for Repetition.** Status: draft 0.1.0 (2026-07-13), recovered and consolidated from the original 2011 design.

isnow describes date/times — from a single fixed instant to complex repetitions — as a compact pattern. Its defining question is a **membership test**:

> Is `*/*/1 * 12:*:00` **now**?

A pattern matches an instant when *every* field's constraint holds for that instant. This is the whole semantics: an implementation exposes `is(pattern, instant) → bool` (and may derive "next occurrence" from it). This is strictly more expressive than cron, which only generates.

The grammar ([IsnowParser.g4](IsnowParser.g4) + [IsnowLexer.g4](IsnowLexer.g4)) recognizes structure and the field algebra; everything labeled **semantic** below is resolved by an implementation walking the parse tree.

## 0. Terminology

Every artifact — this spec, the grammar comments, code identifiers, CLI help, API fields, and docs — uses these names and no synonyms.

- **isnow** — the language, and (as a countable noun) a pattern string in it: *an isnow*, plural *isnows*.
- **instant** — a specific date-time, resolved to the second in a named zone, that an isnow is tested against.
- **holds** — the membership test, the language's defining operation: an isnow *holds at* an instant when every field constraint is satisfied. `is(isnow, instant) → bool`.
- **occurrence** — an instant at which an isnow holds; *next/previous occurrence* are derived from `holds`.
- **canonical form** — the fully-qualified seven-field expansion `Y/m/d w H:M:S`; producing it is **canonicalizing**.
- **shorthand ladder** — the positional default rules (§4) that let a short isnow stand for its canonical form.
- **field** — one of the seven constraint slots (year, month, day, weekday, hour, minute, second); **group** — the date/bare/time runs that carry them; **group separator** — whitespace, `.`, or `_`.
- **algebra** — the uniform per-field constructs: **wildcard** `*`, **exact value**, **set** `,`, **exclusion** `!`, **span** `v-v`, **from-end value** `-v`, **unit compound** `NwNd`, **step** `±[N]` over an **anchor**, and **symbol** (a weekday/time name).
- **since bound** `>`/`>=`, **until bound** `<`/`<=`, and the **window** they define; **field-local** vs **continuous stepping** (§5).
- **nowtab** — a table of `<isnow>  <command>` entries (the crontab analog); **builder** — any interface that composes an isnow from named field inputs.

## 1. Structure

A fully-qualified pattern is seven fields in three groups plus optional bounds:

```
Y/m/d  w  H:M:S    [ >|>= spec ]  [ <|<= spec ]
```

| Field | Group | Separator |
| --- | --- | --- |
| `Y` year, `m` month, `d` day | date group | `/` |
| `w` weekday | bare group | — |
| `H` hour (24), `M` minute, `S` second | time group | `:` |

Groups are separated by whitespace, `.`, or `_` (so a pattern is one shell-safe token): `Y/m/d.w.H:M:S` ≡ `Y/m/d_w_H:M:S` ≡ `Y/m/d w H:M:S`.

## 2. Field algebra (uniform across all seven fields)

Every field is `!v-v±[N]`, any part optional:

| Form | Meaning | Example |
| --- | --- | --- |
| `*` | any value | `*` |
| `v` | exact | `2000`, `Monday`, `12` |
| `a,b,c` | set (union) | `M,W,F`; `1,4,7,10`; `00,15,30,45` |
| `!v` | exclusion ("not") | `/!1` = every day except the 1st |
| `v-v` | inclusive range | `8-12` hours; `M-F`; `1-10`; `29-*` |
| `-v` | count from the end | day `-1` = last of month; `12/-15` = last 15 days of December |
| `-NwNd` | from-end, unit compound | `12/-2w1d` = last 2 weeks 1 day |
| `v+[N]` | increment / nth from start | `Monday+[3]` = 3rd Monday; `:0+[15]` = every 15 min; `M+[1,3]` = 1st and 3rd Monday |
| `v-[N]` | nth from the end | `Thursday-[1]` = last Thursday |
| `+[Nw]` | week-granular increment | `/+[3w]` = every 3rd week of the year (anchor `0` elided) |

Range and increment may co-occur (`v-v±[N]`), and a set distributes the algebra over each member (`1+[4],3+[6]`).

## 3. Symbolic names (semantic, case-insensitive, minimal-unique)

- **Weekdays:** the minimal letters that uniquely identify each — `Su M Tu W Th F Sa` — plus common runs (`MWF`, `SS`, `TT`). A *default* (bare-group) weekday must be symbolic; a numeric weekday `1`–`7` (Sunday = 1) is allowed only in the explicit three-group form (date group, weekday, time group).
- **Times:** `midnight` = `00:00:00`; `noon`/`midday` = `12:00:00` — resolved by unique prefix of the three words plus the abbreviations `mn` (midnight) and `md` (midday). `m` is always Monday (weekday letters win); `mi`/`mid` are ambiguous and rejected.

## 4. Defaults and the shorthand ladder (semantic)

Absent fields default so a short pattern is unambiguous by *separator position*:

- Absent date fields and weekday ⇒ wildcards (`*/*/* *`).
- When no time field is given at all ⇒ `*:*:00`; when any time field is given, absent *finer* time fields ⇒ `00` and absent/empty *coarser* ones ⇒ `*` (so `6` ⇒ `06:00:00` but `:0,30` ⇒ `*:00,30:00`).
- The bare pattern `*` ⇒ `*/*/* * *:*:00` ("every minute").

Which slot a group's fields fill is determined by the group kind and the count of separators present; an implementation maps them onto Y/m/d, w, H/M/S. Illustrative collapses:

| Shorthand | Canonical |
| --- | --- |
| `6` | `*/*/* * 06:00:00` |
| `M noon` | `*/*/* Monday 12:00:00` |
| `/1 18` | `*/*/01 * 18:00:00` |
| `Su :0,30` | `*/*/* Sunday *:00,30:00` |
| `12/-1 0` | `*/12/-01 * 00:00:00` |
| `2000// ::0+[5]` | `2000/*/* * *:*:0+[5]` |

## 5. Bounds and increment context

Start (`>`, `>=`) and end (`<`, `<=`) bounds each carry a full sub-spec:

```
::+[9] >=6 <=18            every 9 seconds from 06:00 to 18:00
12 <9/1                    every day at noon until September 1
/1+[3w] 12 >=2011 <2016    every 3 weeks at noon, for 5 years from 2011
```

Bounds **rebind increment context**: unbounded, `+[N]` resets within its parent field (seconds reset each minute); bounded, the increment counts continuously within each contiguous stretch of the bounded window (a daily time window is one stretch per day), restarting per stretch.

## 6. Grammar vs semantics (the split an implementation owns)

The grammar gives a parse tree of groups → fields → terms. An implementation adds, over that tree:

1. **Group→slot mapping** (§1, §4) — assign each group's fields to Y/m/d, w, or H/M/S by kind and separator count, filling defaults.
2. **Symbol resolution** (§3) — weekday/time NAMEs, and `w`/`d` unit NAMEs.
3. **The matcher** — evaluate `is(pattern, instant)` field by field, honoring sets, ranges, exclusions, from-end counting, increments, and bound-rebound context.

## 7. Out of scope

The original design's **proposals and rejected** extensions are deliberately excluded from this grammar: iteration `{}`, multi-group naming `()`, and the context-switch tick `'` (e.g. `:59'y`). They are recorded in the source history only. `strftime`-substitution was rejected there and stays rejected.
