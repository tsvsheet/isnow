/*
 * IsnowParser.g4 — the parser for isnow / DTimpalr (with IsnowLexer.g4); the
 * executable form of SPECIFICATION.md.
 *
 * A pattern is one line: a `spec` (a whitespace/'.'/'_'-separated sequence of
 * field groups) followed by zero or more start/end `bound`s. Each group is a
 * date group (fields joined by '/'), a time group (fields joined by ':'), or a
 * bare group (a single field — a weekday, or a numeric shorthand). Every field
 * shares ONE algebra: exclusion, sets, ranges, from-end counting, and
 * increments. This uniformity is the language's core idea.
 *
 * WHAT THE GRAMMAR DOES vs DOES NOT do (grammar-first, semantics layered):
 *  - It recognizes the structural form and the full field algebra precisely.
 *  - It does NOT resolve the shorthand ladder — which field a bare group maps
 *    to (a lone `6` ⇒ hour, a lone `M` ⇒ Monday), or the absent-field defaults
 *    (all-dates, `:00` seconds). Those are positional/semantic and belong to the
 *    tree walk, exactly as canonicalization does in UP. An implementation maps
 *    a group's field slots to Y/m/d, w, or H/M/S by the group kind and the
 *    number of separators present.
 *  - Symbolic NAME resolution (case-insensitive, minimal-unique weekday/time
 *    names) and unit NAMEs ('w'/'d') are semantic.
 *
 * Out of scope by design: the rejected/proposed extensions (iteration `{}`,
 * grouping `()`, the context-switch tick `'`) are NOT part of this grammar.
 */
parser grammar IsnowParser;

options { tokenVocab=IsnowLexer; }

// A whole pattern: the main spec, then any start/end bounds and exclusions.
// Leading and trailing group separators are tolerated so callers need not trim.
pattern  : GSEP? spec (bound | exclusion)* GSEP? EOF ;

// A start (>, >=) or end (<, <=) bound carries a full sub-spec whose increments
// are evaluated over the bounded span rather than within their parent field.
bound    : GSEP? boundOp spec ;
boundOp  : GE | GT | LE | LT ;

// A pattern-level exclusion: the pattern never holds when the sub-spec holds
// (`! 12/25` = every day except December 25). The '!' is separated from its
// sub-spec by a group separator, distinguishing it from a field-level exclusion
// (`!12`, no separator, means "not the value 12" within one field).
exclusion : GSEP BANG GSEP spec ;

// A sequence of groups. The loop stops before a `GSEP boundOp` because a bound
// operator can never begin a group, leaving that GSEP for `bound`.
spec     : group (GSEP group)* ;

group
    : dateGroup
    | timeGroup
    | bareGroup
    ;

// Date group: has ≥1 '/', giving year/month/day slots (any may be empty = any).
dateGroup : field? (SLASH field?)+ ;

// Time group: has ≥1 ':', giving hour/minute/second slots (any may be empty).
timeGroup : field? (COLON field?)+ ;

// Bare group: one field, no separator — a weekday or a numeric shorthand.
bareGroup : field ;

// A field: an optional exclusion over a set of one or more terms.
field    : BANG? term (COMMA term)* ;

// A term is the shared per-field algebra: `!v-v±[N]` (exclusion handled above).
//   DASH? atom          → v, or -v (count from the end)
//   (DASH atom)?        → v-v (inclusive range)
//   incr?               → ±[N] increment / nth
// The second alternative is the shorthand where the anchor value is elided and
// only an increment is written (e.g. `/+[3w]`, day field `0+[3w]` with `0` elided).
term
    : DASH? atom (DASH atom)? incr?
    | incr
    ;

// An increment expression: '+' counts from the start / selects the nth
// occurrence; '-' counts from the end. The bracketed list may carry a unit.
incr
    : PLUS LBRACK qty (COMMA qty)* RBRACK
    | DASH LBRACK qty (COMMA qty)* RBRACK
    ;

atom
    : STAR                 // any value
    | NAME                 // weekday or time symbol (Monday, M, MWF, Th, noon, midnight)
    | qty+                 // a numeric value, optionally unit-suffixed (5, 2w1d)
    ;

// A magnitude with an optional unit NAME ('w' week, 'd' day).
qty      : NUMBER NAME? ;
