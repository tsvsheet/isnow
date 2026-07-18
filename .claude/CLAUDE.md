# isnow

> **A date/time pattern language for repetition.** A pattern _matches_ an instant: the language's defining operation is `is(pattern, instant)`, not occurrence generation.

Grammar-first, exactly like [up.grammar](../up.grammar): [IsnowLexer.g4](../isnow/IsnowLexer.g4) + [IsnowParser.g4](../isnow/IsnowParser.g4) are the source of truth; every implementation is generated from them (`make gen`). The grammar carries structure and the uniform per-field algebra; the shorthand ladder, symbolic-name resolution, and the matcher are **semantic**, layered by an implementation over the parse tree ([SPECIFICATION.md](SPECIFICATION.md) §6). Adding wrapper logic that the grammar could express is a language-design alarm — push it into the grammar.

- The seven-field structure, the algebra, and what is in vs out of scope are fixed in [SPECIFICATION.md](SPECIFICATION.md). The rejected/proposed extensions (`{}`, `()`, the `'` context tick) stay out of the grammar.
- The ANTLR/Java toolchain is Docker-isolated ([docker/antlr](docker/antlr/Dockerfile)); generated parsers are never committed here (`gen/` is ignored) — they are lifted into implementation repos.
