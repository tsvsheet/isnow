/*
 * IsnowLexer.g4 — the lexer for isnow (with IsnowParser.g4, the
 * executable form of SPECIFICATION.md). ANTLR requires the file name to match
 * the grammar name, hence the CamelCase.
 *
 * isnow is a date/time PATTERN language: an expression matches an instant when
 * every field's constraint holds. The defining operation is the membership
 * test — `is(pattern, instant)` — not occurrence generation. A pattern is a
 * single line of fields grouped by separator: date fields joined by '/', time
 * fields by ':', a bare weekday/shorthand field between them, and optional
 * start/end bounds introduced by '>' '>=' '<' '<='. Groups are separated by
 * whitespace, '.' or '_'.
 *
 * GRAMMAR-FIRST: the tokens below are purely structural. Symbolic resolution
 * (weekday and time NAMEs — Monday/M/MWF/Th, noon/midnight — are case-
 * insensitive and minimal-unique) and the shorthand ladder (which field a bare
 * token defaults to, and the absent-field defaults — all-dates for a bare time,
 * `:00` seconds for a bare date) are SEMANTIC, resolved by an implementation
 * walking the parse tree — never here.
 * A unit NAME ('w' week, 'd' day) is likewise a plain NAME the parser reads
 * positionally after a NUMBER.
 */
lexer grammar IsnowLexer;

// ---- bound comparators (longer alternative first) -----------------------
GE     : '>=' ;
LE     : '<=' ;
GT     : '>'  ;
LT     : '<'  ;

// ---- field structure ----------------------------------------------------
SLASH  : '/' ;   // date-field separator: year / month / day
COLON  : ':' ;   // time-field separator: hour : minute : second
STAR   : '*' ;   // any value
BANG   : '!' ;   // exclusion ("not")
COMMA  : ',' ;   // set / list of values
DASH   : '-' ;   // range (v-v), from-end value (-v), or nth-from-end (-[N])
PLUS   : '+' ;   // increment (+[N])
LBRACK : '[' ;   // increment expression open
RBRACK : ']' ;   // increment expression close

// ---- lexemes ------------------------------------------------------------
NUMBER : [0-9]+ ;
NAME   : [A-Za-z]+ ;      // weekday/time symbol, or a 'w'/'d' unit — resolved semantically
GSEP   : [ \t._]+ ;       // group separator: whitespace, '.', or '_'
