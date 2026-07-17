.DEFAULT_GOAL := help

# isnow — the one normative grammar for the DTimpalr date/time pattern
# language, generated to every target language so implementations parse from a
# single source of truth.
#
# IsnowLexer.g4 + IsnowParser.g4 are the source of truth (SPECIFICATION.md).
# This Makefile compiles them to each language with ANTLR4. The `go` and `js`
# targets write directly into the sibling implementation repos (the up.grammar
# model): the org tree is mounted so ANTLR can emit into ../isnow.go and
# ../isnow.js. Languages without an implementation repo emit into gen/<lang>/.
# The Java/ANTLR toolchain is isolated in Docker; generated code is committed in
# each implementation, so their normal builds stay toolchain-free.

MAKEFILE_DIR := $(patsubst %/,%,$(dir $(realpath $(lastword $(MAKEFILE_LIST)))))
ORG          := $(realpath $(MAKEFILE_DIR)/..)
ANTLR_IMAGE  := isnow-antlr
LEXER        := IsnowLexer.g4
PARSER       := IsnowParser.g4

# Mount the whole org tree so a target can write into a sibling repo.
RUN := docker run --rm -v "$(ORG)":/work -w /work/isnow $(ANTLR_IMAGE)

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*## "}{printf "  %-10s %s\n", $$1, $$2}'

.PHONY: image
image: docker/antlr/Dockerfile ## Build the pinned ANTLR4 generator image
	docker build -t $(ANTLR_IMAGE) docker/antlr

.PHONY: gen
gen: go js python java cpp ## Generate every target (siblings + gen/<lang>/)

.PHONY: go
go: image ## Generate the Go parser into ../go-isnow/internal/isnowgrammar
	$(RUN) -Dlanguage=Go -package isnowgrammar -o /work/go-isnow/internal/isnowgrammar $(LEXER)
	$(RUN) -Dlanguage=Go -visitor -package isnowgrammar -lib /work/go-isnow/internal/isnowgrammar -o /work/go-isnow/internal/isnowgrammar $(PARSER)
	gofmt -w $(ORG)/go-isnow/internal/isnowgrammar

.PHONY: js
js: image ## Generate the JavaScript parser into ../isnow.js/src/isnowgrammar
	$(RUN) -Dlanguage=JavaScript -o /work/isnow.js/src/isnowgrammar $(LEXER)
	$(RUN) -Dlanguage=JavaScript -visitor -lib /work/isnow.js/src/isnowgrammar -o /work/isnow.js/src/isnowgrammar $(PARSER)

.PHONY: python
python: image ## Generate the Python 3 parser into gen/python
	$(RUN) -Dlanguage=Python3 -o gen/python $(LEXER)
	$(RUN) -Dlanguage=Python3 -visitor -lib gen/python -o gen/python $(PARSER)

.PHONY: java
java: image ## Generate the Java parser into gen/java
	$(RUN) -Dlanguage=Java -package org.uplang.isnowgrammar -o gen/java $(LEXER)
	$(RUN) -Dlanguage=Java -visitor -package org.uplang.isnowgrammar -lib gen/java -o gen/java $(PARSER)

.PHONY: cpp
cpp: image ## Generate the C++ parser into gen/cpp (ANTLR has no plain-C target)
	$(RUN) -Dlanguage=Cpp -o gen/cpp $(LEXER)
	$(RUN) -Dlanguage=Cpp -visitor -lib gen/cpp -o gen/cpp $(PARSER)

.PHONY: corpus
corpus: ## Validate the conformance corpus (YAML well-formed, names unique)
	python3 conformance/validate.py

.PHONY: clean
clean: ## Remove locally generated parsers
	rm -rf gen
