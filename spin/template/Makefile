.DEFAULT_GOAL := all

ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
$(eval $(ARGS):;@:)

.PHONY: all
all:
	opam exec -- dune build --root . @install

.PHONY: deps
deps: ## Install development dependencies
	opam install -y dune-release merlin ocamlformat utop ocaml-lsp-server
	opam install --deps-only --with-test --with-doc -y .

.PHONY: create_switch
create_switch:
	opam switch create . --no-install

.PHONY: switch
switch: create_switch deps ## Create an opam switch and install development dependencies

.PHONY: lock
lock: ## Generate a lock file
	opam lock -y .

.PHONY: build
build: ## Build the project, including non installable libraries and executables
	opam exec -- dune build --root .

.PHONY: install
install: all ## Install the packages on the system
	opam exec -- dune install --root .

.PHONY: sihl
sihl: all ## Run the produced executable
	SIHL_ENV=development opam exec -- dune exec --root . run/run.exe $(ARGS)

.PHONY: test_unit
test-unit: ## Run the unit tests
	SIHL_ENV=test opam exec -- dune runtest

.PHONY: test
test: ## Run the all tests
	SIHL_ENV=test opam exec -- dune build --root . @runtest

.PHONY: clean
clean: ## Clean build artifacts and other generated files
	opam exec -- dune clean --root .

.PHONY: doc
doc: ## Generate odoc documentation
	opam exec -- dune build --root . @doc

.PHONY: format
format: ## Format the codebase with ocamlformat
	opam exec -- dune build --root . --auto-promote @fmt

.PHONE dev:
.SILENT:
.ONESHELL:
dev:    ## Run the Sihl app, watch files and restart on change
	sigint_handler()
	{
	[[ $$(jobs -pr) = "" ]] || kill $$(jobs -pr)
	exit
	}
	trap sigint_handler SIGINT
	while true; do
	dune build
	if [ $$? -eq 0 ]
	then
		SIHL_ENV=development ./_build/default/run/run.exe start &
		PID=$$!
	fi
	echo
	inotifywait -e modify -e move -e create -e delete -e attrib -r `pwd` --exclude "(_build|logs|Makefile)" -qq
	[[ $$(jobs -pr) = "" ]] || kill $$(jobs -pr)
	echo
	done

.PHONY: utop
utop: ## Run a REPL and link with the project's libraries
	opam exec -- dune utop --root . lib -- -implicit-bindings

{% if docker == 'Yes' %}
.PHONY: db
db: ## Starts the database using docker-compose
	docker-compose -f docker/docker-compose.dev.yml up -d

.PHONY: db_down
db_down: ## Removes the database using docker-compose
	docker-compose -f docker/docker-compose.dev.yml down
{% endif %}
