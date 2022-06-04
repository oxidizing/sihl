.DEFAULT_GOAL := all

ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
ARGS := $(subst :,\:,$(ARGS))
$(eval $(ARGS):;@:)

.PHONY: deps
deps:
	opam switch create . 4.12.0 --no-install --locked
	eval $(opam env)
	opam install -y dune-release ocaml-lsp-server ocamlformat ocamlformat-rpc utop
	opam install -y mariadb caqti-driver-postgresql caqti-driver-mariadb
	opam install . -y --deps-only --locked

.PHONY: lock
lock: ## Generate a lock file
	opam lock -y .

.PHONY: format
format: ## Format the codebase with ocamlformat
	opam exec -- dune build --root . --auto-promote @fmt
	dune fmt

.PHONY: db
db: ## Starts the database using docker-compose
	docker-compose -f docker-compose.dev.yml up -d
