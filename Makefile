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

.PHONY: clean
clean: ## Clean build artifacts and other generated files
	opam exec -- dune clean --root .

.PHONY: doc
doc: ## Generate odoc documentation
	opam exec -- dune build --root . @doc

.PHONY: format
format: ## Format the codebase with ocamlformat
	opam exec -- dune build --root . --auto-promote @fmt

.PHONY: sihl
sihl: all ## Run the produced executable of the included Sihl app
	opam exec -- dune exec --root . app/run/run.exe $(ARGS)

.PHONY: test-unit
test-unit: build
	SIHL_ENV=test opam exec -- dune test

.PHONY: test-memory
test-memory: build
	SIHL_ENV=test ./_build/default/sihl-email/test/template.exe
	SIHL_ENV=test ./_build/default/sihl-web/test/bearer_token.exe
	SIHL_ENV=test ./_build/default/sihl-token/test/jwt_inmemory.exe
	SIHL_ENV=test ./_build/default/sihl-queue/test/queue_inmemory.exe

.PHONY: test-mariadb
test-mariadb: build
	SIHL_ENV=test ./_build/default/sihl-email/test/email_mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-persistence/test/database_mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-storage/test/storage_mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-user/test/password_reset_mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-user/test/user_mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-token/test/mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-token/test/jwt_mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-session/test/mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-web/test/csrf_mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-web/test/session_mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-web/test/flash_mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-web/test/user_mariadb.exe
	SIHL_ENV=test ./_build/default/sihl-queue/test/queue_mariadb.exe

.PHONY: test-postgresql
test-postgresql: build
	SIHL_ENV=test ./_build/default/sihl-email/test/email_postgresql.exe
	SIHL_ENV=test ./_build/default/sihl-persistence/test/database_postgresql.exe
	SIHL_ENV=test ./_build/default/sihl-user/test/user_postgresql.exe
	SIHL_ENV=test ./_build/default/sihl-token/test/postgresql.exe
	SIHL_ENV=test ./_build/default/sihl-token/test/jwt_postgresql.exe
	SIHL_ENV=test ./_build/default/sihl-session/test/postgresql.exe
	SIHL_ENV=test ./_build/default/sihl-web/test/session_postgresql.exe
	SIHL_ENV=test ./_build/default/sihl-web/test/flash_postgresql.exe
	SIHL_ENV=test ./_build/default/sihl-queue/test/queue_postgresql.exe

.PHONY: test-http
test-http: build
	SIHL_ENV=test ./_build/default/sihl-web/test/http.exe

.PHONY: test
test: test-unit test-memory test-http test-postgresql test-mariadb

.PHONY: utop
utop: ## Run a REPL and link with the project's libraries
	opam exec -- dune utop --root . lib -- -implicit-bindings

.PHONY: fmt
fmt:
	opam exec -- dune build --root . --auto-promote @fmt

.PHONY: db
db: ## Starts the database using docker-compose
	docker-compose -f docker-compose.dev.yml up -d

.PHONY: db_down
db_down: ## Removes the database using docker-compose
	docker-compose -f docker-compose.dev.yml down
