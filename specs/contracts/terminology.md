# Terminology contract

The single vocabulary for isnow. Every artifact — spec, grammar comments, code identifiers, CLI help, API fields, docs — uses these names and no synonyms. This contract is folded into SPECIFICATION.md as its glossary (language-core capability) and is normative for every implementation.

## The language and its strings

| Term | Definition |
| --- | --- |
| **isnow** | The language, and, as a countable noun, a pattern string in it: _an isnow_, plural _isnows_. "Write an isnow that matches the last Thursday of November." |
| **instant** | A specific date-time, resolved to the second in a named time zone, that an isnow is tested against. |
| **holds** | The membership test, the language's defining operation: an isnow _holds at_ an instant when every field constraint is satisfied. `is(isnow, instant) → bool`. |
| **occurrence** | An instant at which an isnow holds. _Next/previous occurrence_ are derived operations built on `is`. |
| **canonical form** | The fully-qualified seven-field expansion `Y/m/d w H:M:S` of any isnow; producing it is **canonicalizing**. (`6` ⇒ `*/*/* * 06:00:00`.) |
| **shorthand ladder** | The positional default rules (SPECIFICATION.md §4) that let a short isnow stand for its canonical form. |

## Structure

| Term | Definition |
| --- | --- |
| **field** | One of the seven constraint slots: year, month, day, weekday, hour, minute, second. |
| **group** | A run of fields written together: the **date group** (`/`-joined Y/m/d), the **bare group** (a single weekday/shorthand field), the **time group** (`:`-joined H:M:S). |
| **group separator** | Whitespace, `.`, or `_` between groups — what makes an isnow one shell-safe token. |

## The field algebra

| Construct | Term | Example |
| --- | --- | --- |
| `*` | **wildcard** | `*` |
| `v` | **exact value** | `2000`, `12` |
| `a,b,c` | **set** | `M,W,F` |
| `!` | **exclusion** | `!1` |
| `v-v` | **span** (inclusive range) | `8-12`, `M-F` |
| `-v` | **from-end value** | day `-1` = last of month |
| `NwNd` | **unit compound** (units `w` week, `d` day) | `-2w1d` |
| `±[N]` | **step**; the `v` before it is the **anchor** (elided anchor = field start) | `Monday+[3]` = third Monday; `Thursday-[1]` = last Thursday |
| names | **symbol** — case-insensitive, minimal-unique weekday/time names | `M`, `Th`, `MWF`, `noon`, `midnight` |

## Bounds and stepping

| Term | Definition |
| --- | --- |
| **since bound** | `>` / `>=` plus a sub-spec: the earliest instants an isnow can hold. |
| **until bound** | `<` / `<=` plus a sub-spec: the exclusive/inclusive end. |
| **window** | The range of instants a bounded isnow is evaluated over — from its since bound to its until bound, each inclusive or exclusive per its operator. |
| **field-local stepping** | Unbounded step context: a step resets within its parent field (seconds reset each minute). |
| **continuous stepping** | Bounded step context: the step counts within each contiguous stretch of the window, restarting per stretch. (SPECIFICATION.md §5's "increment context rebinding".) |

## Operational vocabulary

| Term | Definition |
| --- | --- |
| **nowtab** | A table file of `<isnow>  <command>` entries — the crontab analog — executed by `isnow run`. |
| **builder** | Any interface (CLI `build`, HTTP `/v1/build`, web playground) that composes an isnow from named field inputs. |

Identifier guidance: Go exports `isnow.Parse`, `isnow.Canonical`, `Pattern.Holds(at)`, `Pattern.Next(from)`; JS mirrors (`parse`, `canonical`, `holds`, `next`). API JSON keys: `isnow`, `canonical`, `at`, `holds`, `occurrences`.
