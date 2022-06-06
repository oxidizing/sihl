.DEFAULT_GOAL := all

ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
ARGS := $(subst :,\:,$(ARGS))
$(eval $(ARGS):;@:)

.PHONY: switch
switch:
	opam switch create . 4.12.0 --no-install --locked
	eval $(opam env)

.PHONY: deps
deps:
	opam install -y odoc dune-release ocaml-lsp-server ocamlformat ocamlformat-rpc utop
	opam install -y ppx_expect mariadb caqti-driver-postgresql caqti-driver-mariadb
	opam install . -y --deps-only --locked

.PHONY: lock
lock: ## Generate a lock file
	opam lock -y .

.PHONY: build
build: ## Build the project, including non installable libraries and executables
	opam exec -- dune build --root .

.PHONY: format
format: ## Format the codebase with ocamlformat & dune
	opam exec -- dune build --root . --auto-promote @fmt

.PHONY: test
test: build	## Run unit tests with dune and then all sihl tests
	opam exec -- dune build --root . @runtest

.PHONY: opam
opam: build	## Fix opam files
	opam lint
	opam exec -- opam-dune-lint

.PHONY: db
db: ## Starts the database using docker-compose
	docker-compose -f docker-compose.dev.yml up -d
